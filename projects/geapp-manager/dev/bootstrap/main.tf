variable "control_project_id" {
  description = "Projeto seed de dev: guarda o WIF do GitHub, a geapp-seed-sa, o state e os releases de dev. Nao e projeto de cliente."
  type        = string
  default     = "geapp-dev-seed-0001"
}

variable "service_account_email" {
  description = "geapp-seed-sa de dev: so cria projetos de clientes de teste (stack project). Criada pelo admin da org, que tambem concede projectCreator na pasta de dev e billing.user no faturamento (README)."
  type        = string
  default     = "geapp-seed-sa@geapp-dev-seed-0001.iam.gserviceaccount.com"
}

variable "clients_folder_id" {
  description = "Pasta de clientes de dev (a mesma da var CLIENTS_FOLDER_ID do environment dev): toda SA nela le os pacotes de release de dev. Vazio ate o admin da org criar a pasta; reaplique com o id."
  type        = string
  default     = ""
}

locals {
  repository = "gentrop-cloud/gentrop-terraform-modules"

  # Apps publicados no bucket de releases de dev (ADR 0010 do geapp-manager): chave =
  # pasta no bucket e sufixo do topico release-<chave>.
  app_repositories = {
    "geapp"       = "gentrop-cloud/gemini-enteprise-adoption-portal"
    "hyper-agent" = "gentrop-cloud/hyper-agent"
  }
}

# A geapp-seed-sa usa o seed como projeto de cota. Sem estas APIs aqui, o stack
# project falha com 403 "API has not been used in project <seed>". A
# tf-provisioner de cada cliente usa o proprio projeto (stacks/project).
resource "google_project_service" "control" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com", # vincular o projeto novo ao faturamento
    "serviceusage.googleapis.com",
    "pubsub.googleapis.com", # topicos de release
  ])

  project            = var.control_project_id
  service            = each.value
  disable_on_destroy = false
}

# Pool proprio do dev seed: a confianca na develop nao alcanca nada do prod.
module "wif" {
  source = "../../../../modules/workload-identity"

  project_id  = var.control_project_id
  pool_id     = "github-terraform"
  provider_id = "terraform-modules"

  # So o provision.yml da develop deste repo troca token por credencial GCP de dev
  # (ADR 0011 do geapp-manager). A main fica com o pool do prod.
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository == \"${local.repository}\" && assertion.ref == \"refs/heads/develop\""

  create_service_account         = false
  existing_service_account_email = var.service_account_email
  github_repositories            = [local.repository]
}

# State proprio do dev, e nao o gentrop-tfstate: o mesmo slug em dev e prod
# apontaria para o mesmo clientes/<slug>/<stack>, e a geapp-seed-sa de dev (que
# ganha storage.admin aqui) alcancaria o state de prod.
resource "google_storage_bucket" "tf_state" {
  project                     = var.control_project_id
  name                        = "${var.control_project_id}-tfstate"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}

# storage.admin, e nao objectAdmin: alem do proprio state, o stack project da a
# tf-provisioner de cada cliente acesso ao bucket.
resource "google_storage_bucket_iam_member" "tf_state" {
  bucket = google_storage_bucket.tf_state.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${module.wif.service_account_email}"
}

output "workload_identity_provider" {
  description = "Vai na var WIF_PROVIDER do environment dev"
  value       = module.wif.workload_identity_provider
}

output "service_account_email" {
  description = "Vai na var SEED_SA_EMAIL do environment dev"
  value       = module.wif.service_account_email
}

output "state_bucket" {
  description = "Vai na var TF_STATE_BUCKET do environment dev"
  value       = google_storage_bucket.tf_state.name
}

# --- Releases dos apps (ADR 0010 do geapp-manager) ----------------------------
# O publish-release.yml da develop de cada app grava o pacote do commit no bucket
# e avisa no topico do app; o trigger de Pub/Sub de cada cliente de dev faz o deploy.

# Pool separado do github-terraform: a confianca nos apps nao alcanca a geapp-seed-sa.
module "release_wif" {
  source = "../../../../modules/workload-identity"

  project_id  = var.control_project_id
  pool_id     = "github-releases"
  provider_id = "app-repos"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository in ${jsonencode(values(local.app_repositories))} && assertion.ref == \"refs/heads/develop\""

  service_account_id           = "release-publisher"
  service_account_display_name = "Publica os pacotes dos apps (publish-release.yml, develop)"
  github_repositories          = values(local.app_repositories)
}

resource "google_storage_bucket" "releases" {
  project                     = var.control_project_id
  name                        = "${var.control_project_id}-releases"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Um pacote por commit da develop; o ponteiro <app>/latest nao casa o sufixo e fica.
  lifecycle_rule {
    condition {
      age            = 180
      matches_suffix = [".tar.gz"]
    }
    action {
      type = "Delete"
    }
  }
}

# objectUser, e nao objectCreator: o workflow reescreve o ponteiro <app>/latest.
resource "google_storage_bucket_iam_member" "release_publisher" {
  bucket = google_storage_bucket.releases.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${module.release_wif.service_account_email}"
}

# Uma permissao so para todos os clientes de dev: a cloud-build-deployer de cada
# projeto na pasta de dev le os pacotes, sem passo por cliente.
resource "google_storage_bucket_iam_member" "clients_read" {
  count = var.clients_folder_id == "" ? 0 : 1

  bucket = google_storage_bucket.releases.name
  role   = "roles/storage.objectViewer"
  member = "principalSet://cloudresourcemanager.googleapis.com/folders/${var.clients_folder_id}/type/ServiceAccount"
}

resource "google_pubsub_topic" "release" {
  for_each = local.app_repositories

  project = var.control_project_id
  name    = "release-${each.key}"

  depends_on = [google_project_service.control]
}

resource "google_pubsub_topic_iam_member" "release_publisher" {
  for_each = google_pubsub_topic.release

  project = var.control_project_id
  topic   = each.value.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${module.release_wif.service_account_email}"
}

# O Pub/Sub ignora a permissao por pasta: o stack project, que roda como a
# geapp-seed-sa, da ao service agent do Cloud Build de cada cliente o subscriber
# (necessario para criar o trigger) nos topicos. Ela so administra estes dois topicos.
resource "google_pubsub_topic_iam_member" "seed_admin" {
  for_each = google_pubsub_topic.release

  project = var.control_project_id
  topic   = each.value.name
  role    = "roles/pubsub.admin"
  member  = "serviceAccount:${module.wif.service_account_email}"
}

output "release_workload_identity_provider" {
  description = "Vai no workload_identity_provider do publish-release.yml da develop dos apps"
  value       = module.release_wif.workload_identity_provider
}

output "release_publisher_email" {
  description = "Vai no service_account do publish-release.yml da develop dos apps"
  value       = module.release_wif.service_account_email
}
