# App do Gemini Enterprise Adoption Portal: o Cloud Run com toda a configuracao,
# o banco e os dados que ele le. O deploy so publica imagens novas.

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  app_service_name = var.client_slug
  # URL deterministica do Cloud Run: conhecida antes do servico existir, entao
  # serve de NEXTAUTH_URL e de redirect URI da credencial OAuth.
  app_url = "https://${local.app_service_name}-${data.google_project.this.number}.${var.region}.run.app"

  # Usuario IAM do Cloud SQL para uma SA: o email sem ".gserviceaccount.com".
  app_db_user = trimsuffix(google_service_account.app.email, ".gserviceaccount.com")

  # Secrets que o app le; o portal grava os valores e manda so os nomes.
  # PRIVATE_KEY/CLIENT_EMAIL: chave da SA de leitura do Firestore do GenGuide.
  app_secret_names = ["NEXTAUTH_SECRET", "GOOGLE_CLIENT_SECRET", "PRIVATE_KEY", "CLIENT_EMAIL"]
}

# Nomes batem com os process.env lidos pelo app (branch Develop). Sem DATABASE_URL:
# com INSTANCE_CONNECTION_NAME o app conecta pelo Cloud SQL connector com IAM.
module "app_run" {
  source     = "../../modules/cloud-run"
  project_id = var.project_id
  location   = var.region

  service_name                   = local.app_service_name
  create_service_account         = false
  existing_service_account_email = google_service_account.app.email
  memory                         = "1Gi"
  allow_unauthenticated          = true

  env_vars = {
    USE_CLOUD_SQL               = "true"
    INSTANCE_CONNECTION_NAME    = module.db.instance_connection_name
    DB_NAME                     = module.db.database_name
    DB_USER                     = local.app_db_user
    NEXTAUTH_URL                = local.app_url
    GOOGLE_CLIENT_ID            = var.google_client_id
    AGENT_PROJECT_ID            = var.project_id
    LOCATION                    = var.region
    RESOURCE_ID                 = basename(module.agent_engine.reasoning_engine_name)
    HYPER_FIRESTORE_PROJECT_ID  = var.project_id
    HYPER_FIRESTORE_DATABASE_ID = local.firestore_database_id
    BIGQUERY_PROJECT_ID         = var.project_id
    BIGQUERY_DATASET_ID         = module.atividade_ge.dataset_id
    FIRESTORE_PROJECT_ID        = var.genguide_project_id
  }
  secret_env_vars = { for k, v in var.secret_env_vars : k => v if contains(local.app_secret_names, k) }

  depends_on = [google_project_iam_member.app, google_project_service.app]
}

# Sem os dois o login do app nao funciona; avisa no log do run sem barrar o apply.
check "app_secrets" {
  assert {
    condition     = alltrue([for k in ["NEXTAUTH_SECRET", "GOOGLE_CLIENT_SECRET"] : contains(keys(var.secret_env_vars), k)]) && var.google_client_id != ""
    error_message = "O app GE precisa de google_client_id e dos secrets NEXTAUTH_SECRET e GOOGLE_CLIENT_SECRET no provisionamento."
  }
}

# Painel de adocao: o app le as tabelas diarias
# discoveryengine_googleapis_com_gemini_enterprise_user_activity_AAAAMMDD, que o
# sink abaixo cria a partir dos logs do Gemini Enterprise. O log de atividade
# precisa estar ligado na configuracao do app no Gemini Enterprise.
module "atividade_ge" {
  source     = "../../modules/bigquery-dataset"
  project_id = var.project_id

  dataset_id                 = "gemini_enterprise_atividade"
  location                   = var.region
  delete_contents_on_destroy = true
}

resource "google_logging_project_sink" "atividade_ge" {
  project     = var.project_id
  name        = "gemini-enterprise-atividade"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${module.atividade_ge.dataset_id}"
  filter      = "log_id(\"discoveryengine.googleapis.com/gemini_enterprise_user_activity\")"

  unique_writer_identity = true
}

resource "google_bigquery_dataset_iam_member" "atividade_ge_sink" {
  project    = var.project_id
  dataset_id = module.atividade_ge.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.atividade_ge.writer_identity
}

resource "google_project_service" "app" {
  for_each = toset([
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "app_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  location   = var.region

  repository_id = "app"
  description   = "Imagens do app Gemini Enterprise Adoption Portal"
}

# SA de runtime do Cloud Run do app. Tambem e a dona das tabelas: as migracoes
# rodam no Cloud Build com o cloud-sql-proxy impersonando esta SA.
resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "app-runtime"
  display_name = "Runtime do app Gemini Enterprise Adoption Portal"
}

resource "google_project_iam_member" "app" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/cloudsql.instanceUser",
    "roles/secretmanager.secretAccessor",
    "roles/aiplatform.user",  # chama o Agent Engine
    "roles/datastore.user",   # le o Firestore do hyper-agent
    "roles/bigquery.jobUser", # dashboard de adocao
    "roles/bigquery.dataViewer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Sufixo aleatorio: o Cloud SQL reserva o nome de uma instancia apagada por ate
# uma semana, e um destroy seguido de novo apply com o mesmo nome falharia.
resource "random_id" "db_suffix" {
  byte_length = 2
}

# Senha do usuario postgres, usada so pelo provider postgresql do modulo para os
# GRANTs. Fica no state (sensivel), excecao aceita: o app e as migracoes usam IAM.
resource "random_password" "db_admin" {
  length  = 32
  special = false
}

module "db" {
  source     = "../../modules/cloud-sql-postgress"
  project_id = var.project_id
  region     = var.region

  instance_name     = "${var.client_slug}-db-${random_id.db_suffix.hex}"
  database_name     = "app"
  db_admin_password = random_password.db_admin.result

  iam_database_users     = [local.app_db_user]
  use_cloudsql_connector = true
  deletion_protection    = false # o portal precisa conseguir destruir o cliente

  # Sem depends_on: o modulo declara o proprio provider postgresql, o que o
  # Terraform nao aceita junto com depends_on. Ele habilita o sqladmin sozinho.
}

# O service agent do Cloud Run precisa de roles/run.serviceAgent. Num projeto em
# que a API foi desligada e religada, o agent e recriado e o papel continua no
# antigo ("deleted:serviceAccount:..."); o Cloud Run fica em "Initializing
# project for the current region" ate estourar o prazo. Garantir aqui cobre isso.
resource "google_project_service_identity" "run" {
  provider = google-beta
  project  = var.project_id
  service  = "run.googleapis.com"

  depends_on = [google_project_service.app]
}

resource "google_project_iam_member" "run_service_agent" {
  project = var.project_id
  role    = "roles/run.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.run.email}"
}
