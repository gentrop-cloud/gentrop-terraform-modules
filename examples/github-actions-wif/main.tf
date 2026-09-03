variable "project_id" {
  description = "GCP project id onde o WIF sera provisionado (a SA sai como github-deployer@<project_id>.iam.gserviceaccount.com)"
  type        = string
}

module "github_wif" {
  source = "../../modules/workload-identity" # Aponta para a pasta local do módulo

  project_id  = var.project_id
  pool_id     = "github-actions-pool"
  provider_id = "github-oidc-provider"

  # restringe a autenticacao aos repositorios listados abaixo
  attribute_condition = "attribute.repository in [\"gentrop-cloud/gentrack\"]"

  service_account_id = "github-deployer"
  service_account_roles = [
    "roles/artifactregistry.admin",       # Administrador do Artifact Registry
    "roles/run.admin",                    # Administrador do Cloud Run
    "roles/artifactregistry.repoAdmin",   # Administrador do repositório do Artifact Registry
    "roles/secretmanager.secretAccessor", # Assessor de secret do Secret Manager
    "roles/cloudsql.client",              # Cliente do Cloud SQL
    "roles/iam.serviceAccountUser",       # Usuário da conta de serviço
    "roles/cloudsql.instanceUser",        # Usuário da instância do Cloud SQL
  ]
  github_repositories = ["gentrop-cloud/gentrack"]
}

output "workload_identity_provider" {
  value = module.github_wif.workload_identity_provider
}

output "service_account_email" {
  value = module.github_wif.service_account_email
}
