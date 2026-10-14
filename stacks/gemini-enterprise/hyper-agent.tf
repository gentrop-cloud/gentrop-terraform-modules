# hyper-agent: Agent Engine, Firestore, BigQuery, Cloud Tasks, Scheduler e os
# 2 Cloud Run. Base: clientes/geapp-prod-hyper-agent, parametrizado.

locals {
  firestore_database_id = "hyper-project-db-native"
  staging_bucket_name   = "${var.project_id}-agent-engine-staging"

  # Formato deterministico do email de SA: referenciar module.gatilho_scheduler
  # dentro do proprio modulo criaria dependencia circular.
  gatilho_scheduler_sa_email = "hyper-agent-gatilho-scheduler@${var.project_id}.iam.gserviceaccount.com"
}

# Discovery Engine: API consumida direto pela aplicacao (telemetria de licencas).
resource "google_project_service" "discovery_engine" {
  project            = var.project_id
  service            = "discoveryengine.googleapis.com"
  disable_on_destroy = false
}

module "firestore" {
  source     = "../../modules/firestore-database"
  project_id = var.project_id

  database_id = local.firestore_database_id
  location_id = var.region

  # Um destroy pelo portal apaga o banco de verdade (o default do provider so o
  # esquece no state, e o apply seguinte falhava com 409).
  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy         = "DELETE"
}

module "auditoria" {
  source     = "../../modules/bigquery-dataset"
  project_id = var.project_id

  dataset_id = "hyper_agent_auditoria"
  location   = var.region

  # Tabelas que o hyper-agent grava ficam fora do Terraform; sem isto o destroy
  # falha com o dataset ainda cheio.
  delete_contents_on_destroy = true
}

module "agent_engine" {
  source     = "../../modules/vertex-ai-agent-engine"
  project_id = var.project_id
  region     = var.region

  display_name        = "hyper-agent-root"
  staging_bucket_name = local.staging_bucket_name

  service_account_id    = "hyper-agent-engine"
  service_account_roles = ["roles/aiplatform.user"]

  # Sem package_spec: o engine nasce vazio e o CI do hyper-agent publica o codigo
  # com agent_engines.update(resource_name=REASONING_ENGINE_ID).
}

# Cloud Run #2: webhook do Google Chat (publico; a app valida o bearer token do
# Chat) e destino das tasks.
module "mensagens_chat" {
  source     = "../../modules/cloud-run"
  project_id = var.project_id
  location   = var.region

  service_name       = "hyper-agent-mensagens-chat"
  service_account_id = "hyper-agent-mensagens-chat"
  service_account_roles = concat(
    ["roles/datastore.user", "roles/bigquery.dataEditor", "roles/aiplatform.user"],
    contains(keys(var.secret_env_vars), "SMTP_PASSWORD") ? ["roles/secretmanager.secretAccessor"] : [],
  )

  allow_unauthenticated = true

  # Env vars e o secret SMTP_PASSWORD vem do cloudbuild.yaml do hyper-agent, no deploy.

  depends_on = [module.firestore]
}

# Cloud Tasks entrega 1 a 1 ao Cloud Run #2, com OIDC da SA do Cloud Run #1.
module "fila_disparos" {
  source     = "../../modules/cloud-tasks-queue"
  project_id = var.project_id
  location   = var.region

  # Sufixo: o Cloud Tasks reserva o nome de uma fila apagada por ate 7 dias, e um
  # destroy seguido de novo apply falharia. O gatilho le o nome via QUEUE_NAME.
  name                      = "fila-disparos-hyperproject-${random_id.db_suffix.hex}"
  max_dispatches_per_second = 1
  max_concurrent_dispatches = 1

  enqueuer_members = ["serviceAccount:${module.gatilho_scheduler.service_account_email}"]
}

# Cloud Run #1: chamado so pelo Cloud Scheduler, fechado.
module "gatilho_scheduler" {
  source     = "../../modules/cloud-run"
  project_id = var.project_id
  location   = var.region

  service_name          = "hyper-agent-gatilho-scheduler"
  service_account_id    = "hyper-agent-gatilho-scheduler"
  service_account_roles = ["roles/datastore.user", "roles/discoveryengine.viewer"]

  allow_unauthenticated = false
  invoker_members = [
    "serviceAccount:${module.disparo_dicas.service_account_email}",
    "serviceAccount:${module.disparo_verificacao.service_account_email}",
  ]

  # Env vars vem do cloudbuild.yaml do hyper-agent, no deploy. PILOT_WHITELIST
  # fica de fora: com ENABLE_WHITELIST=true (default do codigo) ninguem recebe
  # mensagem, que e o lado seguro.

  depends_on = [module.firestore]
}

# O gatilho responde 400 sem {"tipo_gatilho": ...} em JSON.
module "disparo_dicas" {
  source     = "../../modules/cloud-scheduler-http"
  project_id = var.project_id
  region     = var.region

  name               = "hyper-agent-disparo-10h"
  schedule           = "0 10 * * *"
  time_zone          = "America/Sao_Paulo"
  uri                = module.gatilho_scheduler.service_url
  body               = jsonencode({ tipo_gatilho = "dicas" })
  headers            = { "Content-Type" = "application/json" }
  service_account_id = "hyper-agent-disparo-10h"
}

module "disparo_verificacao" {
  source     = "../../modules/cloud-scheduler-http"
  project_id = var.project_id
  region     = var.region

  name               = "hyper-agent-disparo-14h"
  schedule           = "0 14 * * *"
  time_zone          = "America/Sao_Paulo"
  uri                = module.gatilho_scheduler.service_url
  body               = jsonencode({ tipo_gatilho = "verificacao" })
  headers            = { "Content-Type" = "application/json" }
  service_account_id = "hyper-agent-disparo-14h"
}
