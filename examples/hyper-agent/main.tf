locals {
  project_id = "estudos-jean-pereira"
  region     = "us-central1"

  firestore_database_id = "hyper-project-db-native"
  staging_bucket_name   = "${local.project_id}-agent-engine-staging"
}

# Discovery Engine e uma API consumida diretamente pela aplicacao (telemetria
# de licencas) -- nao existe recurso Terraform pra provisionar, so a API.
resource "google_project_service" "discovery_engine" {
  project            = local.project_id
  service            = "discoveryengine.googleapis.com"
  disable_on_destroy = false
}

module "firestore" {
  source     = "../../modules/firestore-database" # Aponta para a pasta local do módulo
  project_id = local.project_id

  database_id = local.firestore_database_id
  location_id = local.region
}

module "auditoria" {
  source     = "../../modules/bigquery-dataset" # Aponta para a pasta local do módulo
  project_id = local.project_id

  dataset_id = "hyper_agent_auditoria"
  location   = local.region
}

module "agent_engine" {
  # count = 0 desliga este modulo enquanto o CI da aplicacao ainda nao subiu
  # o bundle real (pickle + requirements.txt) pro bucket de staging -- o
  # Vertex AI valida/copia esse objeto do GCS na hora de criar o recurso, e
  # falha se ele nao existir. Troque pra count = 1 SO depois de confirmar
  # (gcloud storage ls gs://<bucket>/) que agent.pkl e requirements.txt
  # realmente estao no bucket -- ver README desta pasta.
  count = 0

  source     = "../../modules/vertex-ai-agent-engine" # Aponta para a pasta local do módulo
  project_id = local.project_id
  region     = local.region

  display_name        = "hyper-agent-root"
  staging_bucket_name = local.staging_bucket_name

  # vertex-agent-engine-runtime (o default do modulo) foi deletada numa
  # tentativa anterior e o GCP reserva o nome por um tempo -- usando outro id
  # pra nao esperar essa reserva expirar.
  service_account_id = "vertex-agent-engine-run2"

  service_account_roles = [
    "roles/aiplatform.user",
  ]

  # ATENCAO: o Vertex AI valida e copia o objeto do GCS na hora de criar o
  # recurso -- esses URIs so funcionam depois que o CI da aplicacao subir o
  # bundle real (pickle + requirements.txt) pro bucket de staging via Vertex
  # AI SDK. Ate la, aplique so os outros modulos (veja o README) e deixe
  # este bloco pra depois.
  package_spec = {
    pickle_object_gcs_uri = "gs://${local.staging_bucket_name}/agent.pkl"
    requirements_gcs_uri  = "gs://${local.staging_bucket_name}/requirements.txt"
  }
}

# Cloud Run #2 -- recebe webhooks do Google Chat (publico, verificado no
# codigo da app via bearer token do Chat) e os disparos do Cloud Tasks.
module "mensagens_chat" {
  source     = "../../modules/cloud-run" # Aponta para a pasta local do módulo
  project_id = local.project_id
  location   = local.region

  service_name = "hyper-agent-mensagens-chat"

  service_account_id = "hyper-agent-mensagens-chat"
  service_account_roles = [
    "roles/datastore.user",
    "roles/bigquery.dataEditor",
    "roles/aiplatform.user",
  ]

  # Precisa ficar publico: o webhook do Google Chat nao assina as requisicoes
  # como OIDC do Cloud Run (a app valida o bearer token do Chat no codigo).
  allow_unauthenticated = true

  env_vars = merge(
    {
      FIRESTORE_DATABASE_ID = local.firestore_database_id
      BIGQUERY_DATASET      = module.auditoria.dataset_id
    },
    length(module.agent_engine) > 0 ? { REASONING_ENGINE_NAME = module.agent_engine[0].reasoning_engine_name } : {}
  )

  depends_on = [module.firestore]
}

# Cloud Tasks distribui as chamadas 1 a 1 pro Cloud Run #2, autenticado via
# OIDC com a service account do Cloud Run #1 (quem enfileira as tasks).
module "fila_disparos" {
  source     = "../../modules/cloud-tasks-queue" # Aponta para a pasta local do módulo
  project_id = local.project_id
  location   = local.region

  name = "fila-disparos-hyperproject"

  max_dispatches_per_second = 1
  max_concurrent_dispatches = 1

  enqueuer_members = [
    "serviceAccount:${module.gatilho_scheduler.service_account_email}",
  ]
}

# Cloud Run #1 -- consulta Discovery Engine + Firestore e enfileira tasks.
# Chamado só pelo Cloud Scheduler, então fica fechado (sem allUsers).
module "gatilho_scheduler" {
  source     = "../../modules/cloud-run" # Aponta para a pasta local do módulo
  project_id = local.project_id
  location   = local.region

  service_name = "hyper-agent-gatilho-scheduler"

  service_account_id = "hyper-agent-gatilho-scheduler"
  service_account_roles = [
    "roles/datastore.user",
    "roles/discoveryengine.viewer",
  ]

  allow_unauthenticated = false
  invoker_members = [
    "serviceAccount:${module.disparo_10h.service_account_email}",
    "serviceAccount:${module.disparo_14h.service_account_email}",
  ]

  env_vars = {
    FIRESTORE_DATABASE_ID = local.firestore_database_id
    CLOUD_TASKS_QUEUE_ID  = module.fila_disparos.queue_id
    CLOUD_RUN_TARGET_URL  = module.mensagens_chat.service_url
  }

  depends_on = [module.firestore]
}

module "disparo_10h" {
  source     = "../../modules/cloud-scheduler-http" # Aponta para a pasta local do módulo
  project_id = local.project_id
  region     = local.region

  name               = "hyper-agent-disparo-10h"
  schedule           = "0 10 * * *"
  time_zone          = "America/Sao_Paulo"
  uri                = module.gatilho_scheduler.service_url
  service_account_id = "hyper-agent-disparo-10h"
}

module "disparo_14h" {
  source     = "../../modules/cloud-scheduler-http" # Aponta para a pasta local do módulo
  project_id = local.project_id
  region     = local.region

  name               = "hyper-agent-disparo-14h"
  schedule           = "0 14 * * *"
  time_zone          = "America/Sao_Paulo"
  uri                = module.gatilho_scheduler.service_url
  service_account_id = "hyper-agent-disparo-14h"
}

output "mensagens_chat_url" {
  value = module.mensagens_chat.service_url
}

output "gatilho_scheduler_url" {
  value = module.gatilho_scheduler.service_url
}

output "firestore_database" {
  value = module.firestore.name
}

output "bigquery_dataset" {
  value = module.auditoria.dataset_id
}

output "reasoning_engine_name" {
  value = length(module.agent_engine) > 0 ? module.agent_engine[0].reasoning_engine_name : null
}
