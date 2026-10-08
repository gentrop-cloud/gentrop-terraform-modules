# App do Gemini Enterprise Adoption Portal: tudo que o deploy (Cloud Build)
# precisa encontrar pronto no projeto do cliente.

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
