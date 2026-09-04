# Credencial OAuth 2.0 (Client ID / Secret) NAO da pra automatizar via Terraform -- a
# Google nao tem API/recurso pra criar isso (so o Console mesmo). Os defaults abaixo
# sao FICTICIOS, so pra o apply rodar de ponta a ponta sem travar -- o login com
# Google nao funciona ate voce trocar pelos valores reais. Depois de criar a
# credencial em APIs & Services > Credentials (usando o output "oauth_redirect_uri"
# como "Authorized redirect URI"), sobrescreva num terraform.tfvars (ja e ignorado
# pelo git), sem editar os defaults aqui:
#   google_client_id     = "<seu client id real>.apps.googleusercontent.com"
#   google_client_secret = "<seu client secret real, comeca com GOCSPX->"
variable "google_client_id" {
  description = "Client ID da credencial OAuth 2.0 criada no Console"
  type        = string
  default     = "TROQUE-PELO-SEU-CLIENT-ID.apps.googleusercontent.com"
}

variable "google_client_secret" {
  description = "Client Secret da credencial OAuth 2.0 criada no Console"
  type        = string
  default     = "TROQUE-PELO-SEU-CLIENT-SECRET"
  sensitive   = true
}

locals {
  project_id = "estudos-jean-pereira"
  region     = "us-central1"

  # Rede autorizada a conectar direto no Cloud SQL (IP publico) -- necessario so
  # porque o modulo cloud-sql-postgress roda GRANTs via conexao direta na hora do
  # apply. Troque pelo IP publico de quem roda o terraform apply.
  authorized_networks = [
    {
      name  = "acesso-terraform-apply"
      value = "0.0.0.0/0" # RESTRINJA para o seu IP antes de usar fora de teste
    }
  ]
}

data "google_project" "this" {
  project_id = local.project_id
}

locals {
  # URL deterministica do Cloud Run: previsivel mesmo antes do servico existir,
  # entao da pra usar como redirect URI da credencial OAuth sem depender dele.
  cloud_run_url      = "https://${local.project_id}-${data.google_project.this.number}.${local.region}.run.app"
  oauth_redirect_uri = "${local.cloud_run_url}/api/auth/callback/google"
}

module "registry" {
  source     = "../../modules/artifact-registry" # Aponta para a pasta local do módulo
  project_id = local.project_id
}

resource "random_password" "db_admin" {
  length  = 24
  special = true
}

module "db" {
  source     = "../../modules/cloud-sql-postgress" # Aponta para a pasta local do módulo
  project_id = local.project_id

  instance_name       = "${local.project_id}-db"
  database_name       = "app"
  region              = local.region
  db_admin_password   = random_password.db_admin.result
  authorized_networks = local.authorized_networks
}

resource "random_password" "nextauth_secret" {
  length  = 32
  special = false
}

module "secrets" {
  source     = "../../modules/secret-manager" # Aponta para a pasta local do módulo
  project_id = local.project_id

  secret_ids = [
    "NEXTAUTH_SECRET",
    "GOOGLE_CLIENT_SECRET",
    "DATABASE_URL",
    "DIRECT_URL",
  ]
}

locals {
  database_url = "postgresql://postgres:${random_password.db_admin.result}@localhost/${module.db.database_name}?host=/cloudsql/${module.db.instance_connection_name}"
}

resource "google_secret_manager_secret_version" "values" {
  for_each = {
    NEXTAUTH_SECRET      = random_password.nextauth_secret.result
    GOOGLE_CLIENT_SECRET = var.google_client_secret
    DATABASE_URL         = local.database_url
    DIRECT_URL           = local.database_url
  }

  secret      = module.secrets.secret_names[each.key]
  secret_data = each.value
}

module "app" {
  source     = "../../modules/cloud-run" # Aponta para a pasta local do módulo
  project_id = local.project_id

  service_name             = local.project_id
  location                 = local.region
  cloudsql_connection_name = module.db.instance_connection_name

  service_account_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/cloudsql.client",
  ]

  env_vars = {
    GOOGLE_CLIENT_ID = var.google_client_id
    NEXTAUTH_URL     = local.cloud_run_url
  }

  # nome da secret == nome da env var nesse setup, entao o mapa inteiro serve direto
  secret_env_vars = module.secrets.secret_ids

  depends_on = [google_secret_manager_secret_version.values]
}

output "oauth_redirect_uri" {
  description = "Cole isso como 'Authorized redirect URI' ao criar a credencial OAuth no Console"
  value       = local.oauth_redirect_uri
}

output "repository_url" {
  value = module.registry.repository_url
}

output "service_url" {
  value = module.app.service_url
}

output "service_account_email" {
  value = module.app.service_account_email
}
