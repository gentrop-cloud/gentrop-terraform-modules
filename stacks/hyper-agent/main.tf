# Stack do gentrop-cloud/hyper-agent aplicado pelo geapp-portal (provision.yml),
# um state por cliente. Base: clientes/geapp-prod-hyper-agent, parametrizado.
#
# Diferencas em relacao ao root manual:
# - Sem module.secrets nem versao de SMTP_PASSWORD: o portal grava o valor no
#   Secret Manager do cliente e passa so o nome em secret_env_vars.
# - Sem WIF para o GitHub Actions do hyper-agent: o deploy nos clientes vai
#   ser feito pelo Cloud Build (fluxo em desenho).
# - Agent Engine em duas fases (enable_agent_engine), porque o Vertex AI exige
#   o bundle no bucket de staging na hora de criar o recurso.
# - Cloud Scheduler envia o body {"tipo_gatilho": ...} que o gatilho exige.

variable "project_id" {
  description = "Projeto GCP do cliente"
  type        = string
}

variable "client_slug" {
  description = "Slug do cliente no portal (o portal sempre envia; os recursos daqui tem nome fixo, um hyper-agent por projeto)"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "secret_env_vars" {
  description = "Env var do Cloud Run de mensagens => id do secret no Secret Manager do cliente (ex.: SMTP_PASSWORD)"
  type        = map(string)
  default     = {}
}

variable "enable_agent_engine" {
  description = "false no primeiro apply. Depois que o CI do hyper-agent subir agent.pkl e requirements.txt no bucket de staging, aplique de novo com true."
  type        = bool
  default     = false
}

variable "smtp_email" {
  description = "Remetente do fallback de e-mail"
  type        = string
  default     = "automacao@gentrop.com"
}

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

module "registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  location   = var.region

  repository_id = "hyper-agent"
  description   = "Imagens dos 2 Cloud Run do hyper-agent"
}

module "firestore" {
  source     = "../../modules/firestore-database"
  project_id = var.project_id

  database_id = local.firestore_database_id
  location_id = var.region
}

module "auditoria" {
  source     = "../../modules/bigquery-dataset"
  project_id = var.project_id

  dataset_id = "hyper_agent_auditoria"
  location   = var.region
}

module "agent_engine" {
  source     = "../../modules/vertex-ai-agent-engine"
  project_id = var.project_id
  region     = var.region

  display_name            = "hyper-agent-root"
  staging_bucket_name     = local.staging_bucket_name
  create_reasoning_engine = var.enable_agent_engine

  service_account_id    = "hyper-agent-engine"
  service_account_roles = ["roles/aiplatform.user"]

  package_spec = {
    pickle_object_gcs_uri = "gs://${local.staging_bucket_name}/agent.pkl"
    requirements_gcs_uri  = "gs://${local.staging_bucket_name}/requirements.txt"
  }
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
    length(var.secret_env_vars) > 0 ? ["roles/secretmanager.secretAccessor"] : [],
  )

  allow_unauthenticated = true

  # Nomes batem com os os.environ lidos em cloud_run/hyper-agent-mensagens-chat/main.py.
  env_vars = merge(
    {
      GOOGLE_CLOUD_PROJECT  = var.project_id
      GOOGLE_CLOUD_LOCATION = var.region
      SMTP_EMAIL            = var.smtp_email
    },
    # REASONING_ENGINE_ID e obrigatorio no codigo: so existe com o Agent Engine ligado.
    var.enable_agent_engine ? { REASONING_ENGINE_ID = module.agent_engine.reasoning_engine_name } : {},
  )
  secret_env_vars = var.secret_env_vars

  depends_on = [module.firestore]
}

# Cloud Tasks entrega 1 a 1 ao Cloud Run #2, com OIDC da SA do Cloud Run #1.
module "fila_disparos" {
  source     = "../../modules/cloud-tasks-queue"
  project_id = var.project_id
  location   = var.region

  name                      = "fila-disparos-hyperproject"
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

  # Nomes batem com os os.environ.get lidos em cloud_run/hyper-agent-gatilho-scheduler/main.py.
  # PILOT_WHITELIST fica de fora: com ENABLE_WHITELIST=true (default do codigo)
  # ninguem recebe mensagem, que e o lado seguro.
  env_vars = {
    PROJECT_ID       = var.project_id
    LOCATION         = "global"
    REGION_TASKS     = var.region
    QUEUE_NAME       = module.fila_disparos.queue_name
    AGENT_ENDPOINT   = module.mensagens_chat.service_url
    SA_EMAIL_INVOKER = local.gatilho_scheduler_sa_email
  }

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

output "mensagens_chat_url" {
  value = module.mensagens_chat.service_url
}

output "gatilho_scheduler_url" {
  value = module.gatilho_scheduler.service_url
}

output "artifact_registry_url" {
  value = module.registry.repository_url
}

output "agent_engine_staging_bucket" {
  value = "gs://${module.agent_engine.staging_bucket_name}"
}

output "reasoning_engine_name" {
  value = module.agent_engine.reasoning_engine_name
}

output "firestore_database" {
  value = module.firestore.name
}

output "bigquery_dataset" {
  value = module.auditoria.dataset_id
}
