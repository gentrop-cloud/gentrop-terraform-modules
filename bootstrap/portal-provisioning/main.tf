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

locals {
  repository = "gentrop-cloud/gentrop-terraform-modules"
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
