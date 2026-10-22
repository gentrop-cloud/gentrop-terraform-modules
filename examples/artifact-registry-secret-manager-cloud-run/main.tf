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
  project_id = "geapp-gentrop-prod-0001" // adicionar no projeto aqui
  region     = "us-central1"

  # Redes autorizadas a conectar direto no Cloud SQL (IP publico). Vazio: so o
  # Cloud Run (via Cloud SQL connector) acessa. So e necessario liberar o IP de
  # quem roda o apply (/32) se usar iam_database_users, pois o modulo roda GRANTs
  # via conexao direta.
  authorized_networks = []
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
  database_version    = "POSTGRES_18"
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
    "AGENT_PROJECT_ID",
    "APP_SERVICE_ACCOUNT",
    "DB_USER",
    "DB_USER_ENCODED",
    "FIRESTORE_PROJECT_ID",
    "GOOGLE_CLIENT_ID",
    "HYPER_FIRESTORE_DATABASE_ID",
    "HYPER_FIRESTORE_PROJECT_ID",
    "IDENTITY_POOL",
    "IDENTITY_SA",
    "IMAGE_REGISTRY",
    "INSTANCE_CONNECTION_NAME",
    "LOCATION",
    "NEXTAUTH_URL",
    "PROJECT_ID",
    "RESOURCE_ID",
    "SERVICE_NAME_CLIENT"
  ]
}

locals {
  app_env_vars = {
    GOOGLE_CLIENT_ID = var.google_client_id
    NEXTAUTH_URL     = local.cloud_run_url
  }

  database_url = "postgresql://postgres:${random_password.db_admin.result}@localhost/${module.db.database_name}?host=/cloudsql/${module.db.instance_connection_name}"
}

resource "google_secret_manager_secret_version" "values" {
  # Cloud Run exige que toda secret referenciada ("latest") tenha ao menos uma versao.
  # GOOGLE_CLIENT_ID e NEXTAUTH_URL ficam de fora: vao como env comum (app_env_vars).
  for_each = {
    LOCATION                 = local.region
    PROJECT_ID               = local.project_id
    DB_USER                  = "postgres"
    DB_USER_ENCODED          = urlencode("postgres")
    INSTANCE_CONNECTION_NAME = module.db.instance_connection_name
    IMAGE_REGISTRY           = module.registry.repository_url
    APP_SERVICE_ACCOUNT      = "cloud-run-runtime@${local.project_id}.iam.gserviceaccount.com"
    SERVICE_NAME_CLIENT      = local.project_id
    AGENT_PROJECT_ID         = local.project_id
    FIRESTORE_PROJECT_ID     = local.project_id

    # Vem de outros examples (hyper-agent / github-actions-wif) ou do Agent Engine:
    # placeholders ficticios, troque pelos valores reais (nova versao da secret).
    HYPER_FIRESTORE_PROJECT_ID  = local.project_id
    HYPER_FIRESTORE_DATABASE_ID = "hyper-project-db-native"
    IDENTITY_POOL               = "TROQUE-PELO-WORKLOAD-IDENTITY-PROVIDER"
    IDENTITY_SA                 = "TROQUE-PELA-SA-DO-DEPLOYER"
    RESOURCE_ID                 = "TROQUE-PELO-RESOURCE-ID-DO-AGENT-ENGINE"
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

  env_vars = local.app_env_vars

  # nome da secret == nome da env var; exclui as que ja vao como env comum (Cloud Run rejeita nome duplicado)
  secret_env_vars = { for k, v in module.secrets.secret_ids : k => v if !contains(keys(local.app_env_vars), k) }

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
