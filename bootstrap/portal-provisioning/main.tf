variable "control_project_id" {
  description = "Projeto seed: guarda o WIF do GitHub e a geapp-seed-sa. Nao e projeto de cliente nem de prod."
  type        = string
  default     = "geapp-prod-seed-0001"
}

variable "service_account_email" {
  description = "geapp-seed-sa: so cria projetos de clientes (stack project). Criada pelo admin da org, que tambem concede projectCreator na pasta e billing.user no faturamento (README)."
  type        = string
  default     = "geapp-seed-sa@geapp-prod-seed-0001.iam.gserviceaccount.com"
}

variable "state_bucket" {
  description = "Bucket de state compartilhado (ja existente)"
  type        = string
  default     = "gentrop-tfstate"
}

variable "clients_folder_id" {
  description = "Pasta de clientes (a mesma da var CLIENTS_FOLDER_ID do repo): toda SA nela le os pacotes de release"
  type        = string
  default     = "540065658735"
}

locals {
  repository = "gentrop-cloud/gentrop-terraform-modules"

  # Apps publicados no bucket de releases (ADR 0010 do geapp-portal): chave = pasta
  # no bucket e sufixo do topico release-<chave>.
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
    "secretmanager.googleapis.com", # PAT do Cloud Build, abaixo
    "pubsub.googleapis.com",        # topicos de release
  ])

  project            = var.control_project_id
  service            = each.value
  disable_on_destroy = false
}

# Pool proprio: nao reaproveita o github-actions-pool / github-deployer do
# examples/github-actions-wif, que serve ao deploy de apps e tem outros papeis.
module "wif" {
  source = "../../modules/workload-identity"

  project_id  = var.control_project_id
  pool_id     = "github-terraform"
  provider_id = "terraform-modules"

  # So o provision.yml da main deste repo troca token por credencial GCP.
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository == \"${local.repository}\" && assertion.ref == \"refs/heads/main\""

  create_service_account         = false
  existing_service_account_email = var.service_account_email
  github_repositories            = [local.repository]
}

# storage.admin, e nao objectAdmin: alem do proprio state, o stack project da a
# tf-provisioner de cada cliente acesso ao bucket.
resource "google_storage_bucket_iam_member" "tf_state" {
  bucket = var.state_bucket
  role   = "roles/storage.admin"
  member = "serviceAccount:${module.wif.service_account_email}"
}

output "workload_identity_provider" {
  description = "Vai na var WIF_PROVIDER do repo"
  value       = module.wif.workload_identity_provider
}

output "service_account_email" {
  description = "Vai na var SEED_SA_EMAIL do repo"
  value       = module.wif.service_account_email
}

# PAT classico do GitHub (repo, read:user, read:org) usado pela conexao do Cloud
# Build de cada cliente. So o container e criado aqui; o valor entra a mao:
#   printf '%s' "<token>" | gcloud secrets versions add cloudbuild-github-token --data-file=- --project=geapp-prod-seed-0001
resource "google_secret_manager_secret" "cloudbuild_github_token" {
  project   = var.control_project_id
  secret_id = "cloudbuild-github-token"

  replication {
    user_managed {
      replicas {
        location = "us-central1"
      }
    }
  }

  depends_on = [google_project_service.control]
}

# O stack project da admin deste secret a tf-provisioner de cada cliente, que da
# leitura nele ao service agent do Cloud Build do cliente.
resource "google_secret_manager_secret_iam_member" "tf_github_token" {
  secret_id = google_secret_manager_secret.cloudbuild_github_token.id
  role      = "roles/secretmanager.admin"
  member    = "serviceAccount:${module.wif.service_account_email}"
}

output "cloudbuild_github_token_secret" {
  description = "Vai na var CLOUDBUILD_GITHUB_TOKEN_SECRET do repo"
  value       = google_secret_manager_secret.cloudbuild_github_token.id
}

# --- Releases dos apps (ADR 0010 do geapp-portal) ----------------------------
# O publish-release.yml da main de cada app grava o pacote do commit no bucket e
# avisa no topico do app; o trigger de Pub/Sub de cada cliente faz o deploy. Nenhum
# projeto de cliente guarda credencial do GitHub.

# Pool separado do github-terraform: a confianca nos apps nao alcanca a geapp-seed-sa.
module "release_wif" {
  source = "../../modules/workload-identity"

  project_id  = var.control_project_id
  pool_id     = "github-releases"
  provider_id = "app-repos"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository in ${jsonencode(values(local.app_repositories))} && assertion.ref == \"refs/heads/main\""

  service_account_id           = "release-publisher"
  service_account_display_name = "Publica os pacotes dos apps (publish-release.yml)"
  github_repositories          = values(local.app_repositories)
}

# Criados no POC do ADR 0010, antes deste codigo.
import {
  to = google_storage_bucket.releases
  id = "geapp-prod-seed-0001-releases"
}

import {
  to = google_pubsub_topic.release["geapp"]
  id = "projects/geapp-prod-seed-0001/topics/release-geapp"
}

import {
  to = google_pubsub_topic.release["hyper-agent"]
  id = "projects/geapp-prod-seed-0001/topics/release-hyper-agent"
}

resource "google_storage_bucket" "releases" {
  project                     = var.control_project_id
  name                        = "${var.control_project_id}-releases"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Um pacote por commit da main; o ponteiro <app>/latest nao casa o sufixo e fica.
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

# Uma permissao so para todos os clientes: a cloud-build-deployer de cada projeto
# na pasta le os pacotes, sem passo por cliente.
resource "google_storage_bucket_iam_member" "clients_read" {
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
  description = "Vai no workload_identity_provider do publish-release.yml dos apps"
  value       = module.release_wif.workload_identity_provider
}

output "release_publisher_email" {
  description = "Vai no service_account do publish-release.yml dos apps"
  value       = module.release_wif.service_account_email
}
