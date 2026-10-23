# Hospedagem do GeApp Manager de dev no geapp-dev-seed-0001 (ADR 0011 do
# geapp-manager). O deploy.yml da develop do gentrop-geapp-manager builda, migra e
# publica; este root so cria o que o deploy usa. Imagem e env vars do Cloud Run sao
# do deploy (o modulo cloud-run ignora as duas).

variable "project_id" {
  description = "Projeto seed de dev, onde o manager de dev roda"
  type        = string
  default     = "geapp-dev-seed-0001"
}

locals {
  region     = "us-central1"
  repository = "gentrop-cloud/gentrop-geapp-manager"

  # Valores entram a mao (README do bootstrap de dev); o deploy.yml referencia cada
  # um como NAME=<secret>:latest. database-url e o unico gravado aqui.
  secret_ids = [
    "database-url",
    "session-secret",
    "google-client-id",
    "google-client-secret",
    "github-app-id",
    "github-app-private-key",
    "admin-emails",
  ]
}

resource "google_project_service" "this" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "registry" {
  source = "../../../../modules/artifact-registry"

  project_id    = var.project_id
  location      = local.region
  repository_id = "geapp-manager"
  description   = "Imagens do GeApp Manager (deploy.yml da develop)"
}

# Replicacao em us-central1, e nao auto: todo recurso do manager fica na regiao.
resource "google_secret_manager_secret" "this" {
  for_each = toset(local.secret_ids)

  project   = var.project_id
  secret_id = each.value

  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }

  depends_on = [google_project_service.this]
}

resource "google_sql_database_instance" "manager" {
  project             = var.project_id
  name                = "geapp-manager"
  database_version    = "POSTGRES_17"
  region              = local.region
  deletion_protection = true

  settings {
    tier = "db-f1-micro"

    # IP publico sem redes autorizadas: so entra pelo proxy/conector, com IAM.
    ip_configuration {
      ipv4_enabled = true
    }
  }

  depends_on = [google_project_service.this]
}

resource "google_sql_database" "geapp" {
  project  = var.project_id
  name     = "geapp"
  instance = google_sql_database_instance.manager.name
}

# shortcut: usuario por senha, com a senha no state deste root (gentrop-tfstate).
# O postgres.js nao faz IAM auth pelo socket do Cloud Run; trocar pelo conector com
# IAM auth quando rotacao ou auditoria pedirem (ADR 0011 do geapp-manager).
resource "random_password" "db" {
  length  = 32
  special = false # vai cru na URL do DATABASE_URL
}

resource "google_sql_user" "geapp" {
  project  = var.project_id
  name     = "geapp"
  instance = google_sql_database_instance.manager.name
  password = random_password.db.result
}

# localhost:5432 e o proxy da migracao no deploy.yml. No Cloud Run, a env
# DATABASE_SOCKET=/cloudsql/<conexao> faz o manager usar o socket montado.
resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.this["database-url"].id
  secret_data = "postgres://geapp:${random_password.db.result}@localhost:5432/geapp"
}

# Publico: a app faz o login Google e os callbacks do provision.yml trazem OIDC do
# GitHub. Sem IAP, que consumiria o header Authorization dos callbacks.
module "service" {
  source = "../../../../modules/cloud-run"

  project_id                   = var.project_id
  location                     = local.region
  service_name                 = "geapp-manager"
  service_account_id           = "geapp-manager"
  service_account_display_name = "GeApp Manager (dev)"
  service_account_roles        = ["roles/cloudsql.client"]
  cloudsql_connection_name     = google_sql_database_instance.manager.connection_name
  allow_unauthenticated        = true
}

resource "google_secret_manager_secret_iam_member" "runtime" {
  for_each = google_secret_manager_secret.this

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.service.service_account_email}"
}

# Pool proprio do deploy: so a develop do repo do manager assume a deployer.
module "deployer_wif" {
  source = "../../../../modules/workload-identity"

  project_id  = var.project_id
  pool_id     = "github-deploy"
  provider_id = "geapp-manager"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository == \"${local.repository}\" && assertion.ref == \"refs/heads/develop\""

  service_account_id           = "geapp-manager-deployer"
  service_account_display_name = "Deploy do GeApp Manager (deploy.yml, develop)"
  service_account_roles = [
    "roles/run.developer",
    "roles/artifactregistry.writer",
    "roles/cloudsql.client", # proxy da migracao
  ]
  github_repositories = [local.repository]
}

# O deploy publica revisoes que rodam como a SA de runtime.
resource "google_service_account_iam_member" "deployer_act_as" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${module.service.service_account_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${module.deployer_wif.service_account_email}"
}

# A migracao le so o DATABASE_URL; os outros secrets so a runtime le.
resource "google_secret_manager_secret_iam_member" "deployer_database_url" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.this["database-url"].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.deployer_wif.service_account_email}"
}

output "service_url" {
  description = "Vai na var PORTAL_URL do environment dev dos dois repos"
  value       = module.service.service_url
}

output "runtime_service_account" {
  description = "Vai na var PORTAL_SA_EMAIL do environment dev do gentrop-terraform-modules"
  value       = module.service.service_account_email
}

output "cloud_sql_connection" {
  description = "Vai na var CLOUD_SQL_CONNECTION do environment dev do gentrop-geapp-manager"
  value       = google_sql_database_instance.manager.connection_name
}

output "deployer_workload_identity_provider" {
  description = "Vai na var WIF_PROVIDER do environment dev do gentrop-geapp-manager"
  value       = module.deployer_wif.workload_identity_provider
}

output "deployer_service_account" {
  description = "Vai na var DEPLOYER_SA do environment dev do gentrop-geapp-manager"
  value       = module.deployer_wif.service_account_email
}
