# SMTP_PASSWORD real NAO da pra automatizar via Terraform -- e a senha de app
# do Gmail usado como fallback de e-mail. O default abaixo e FICTICIO, so pra
# o apply rodar de ponta a ponta; sobrescreva num terraform.tfvars (ja e
# ignorado pelo git), sem editar o default aqui:
#   smtp_password = "<senha de app real>"
variable "smtp_password" {
  description = "Senha de app SMTP (Gmail) usada pelo Cloud Run 2 pro fallback de e-mail."
  type        = string
  default     = "TROQUE-PELA-SUA-SENHA-DE-APP"
  sensitive   = true
}

locals {
  project_id = "geapp-gentrop-prod-0001"
  region     = "us-central1"

  firestore_database_id = "hyper-project-db-native"
  staging_bucket_name   = "${local.project_id}-agent-engine-staging"

  # Formato deterministico do email de SA do GCP -- usado pra injetar a
  # propria SA do gatilho_scheduler como env var nele mesmo (referenciar
  # module.gatilho_scheduler dentro do proprio bloco do modulo criaria uma
  # dependencia circular).
  gatilho_scheduler_sa_email = "hyper-agent-gatilho-scheduler@${local.project_id}.iam.gserviceaccount.com"
}

# Discovery Engine e uma API consumida diretamente pela aplicacao (telemetria
# de licencas) -- nao existe recurso Terraform pra provisionar, so a API.
resource "google_project_service" "discovery_engine" {
  project            = local.project_id
  service            = "discoveryengine.googleapis.com"
  disable_on_destroy = false
}

# Cloud Build: o deploy.yml do hyper-agent builda as imagens dos Cloud Run com
# `gcloud builds submit`.
resource "google_project_service" "cloud_build" {
  project            = local.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# App Hub: so o console do Vertex AI Agent Engine usa pra exibir os detalhes do
# agente; o Agent Engine funciona sem ela.
resource "google_project_service" "apphub" {
  project            = local.project_id
  service            = "apphub.googleapis.com"
  disable_on_destroy = false
}

module "registry" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/artifact-registry?ref=v1.0.0"
  project_id = local.project_id
  location   = local.region

  repository_id = "hyper-agent"
  description   = "Imagens dos 2 Cloud Run do hyper-agent"
}

module "secrets" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/secret-manager?ref=v1.0.0"
  project_id = local.project_id

  secret_ids = ["SMTP_PASSWORD"]
}

resource "google_secret_manager_secret_version" "smtp_password" {
  secret      = module.secrets.secret_names["SMTP_PASSWORD"]
  secret_data = var.smtp_password
}

# CI/CD (GitHub Actions do repo gentrop-cloud/hyper-agent) autentica via WIF,
# sem chave de service account. Ver DEPLOY.md nesse repo pra saber onde cada
# output abaixo entra nos Secrets/Variables do GitHub.
module "github_wif" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/workload-identity?ref=v1.0.0"
  project_id = local.project_id

  pool_id     = "hyper-agent-gh-pool"
  provider_id = "hyper-agent-gh-provider"

  attribute_condition = "attribute.repository == 'gentrop-cloud/hyper-agent'"
  github_repositories = ["gentrop-cloud/hyper-agent"]

  service_account_id = "hyper-agent-gh-deployer"
  service_account_roles = [
    "roles/run.admin",                         # deploy das revisions do Cloud Run
    "roles/artifactregistry.writer",           # push de imagem
    "roles/iam.serviceAccountUser",            # deploy age como a SA de runtime de cada servico
    "roles/aiplatform.user",                   # agent_engines.update no Reasoning Engine
    "roles/storage.admin",                     # staging do Agent Engine + bucket <projeto>_cloudbuild (precisa de buckets.get)
    "roles/cloudbuild.builds.editor",          # gcloud builds submit
    "roles/serviceusage.serviceUsageConsumer", # checado pelo gcloud builds submit
  ]
}

module "firestore" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/firestore-database?ref=v1.0.0"
  project_id = local.project_id

  database_id = local.firestore_database_id
  location_id = local.region
}

module "auditoria" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/bigquery-dataset?ref=v1.0.0"
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
  count = 1

  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/vertex-ai-agent-engine?ref=v1.0.0"
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
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
  project_id = local.project_id
  location   = local.region

  service_name = "hyper-agent-mensagens-chat"

  service_account_id = "hyper-agent-mensagens-chat"
  service_account_roles = [
    "roles/datastore.user",
    "roles/bigquery.dataEditor",
    "roles/aiplatform.user",
    "roles/secretmanager.secretAccessor",
  ]

  # Precisa ficar publico: o webhook do Google Chat nao assina as requisicoes
  # como OIDC do Cloud Run (a app valida o bearer token do Chat no codigo).
  allow_unauthenticated = true

  # Nomes tem que bater com os `os.environ[...]`/`os.environ.get(...)` lidos
  # em cloud_run/hyper-agent-mensagens-chat/main.py.
  env_vars = merge(
    {
      GOOGLE_CLOUD_PROJECT  = local.project_id
      GOOGLE_CLOUD_LOCATION = local.region
      SMTP_EMAIL            = "automacao@gentrop.com"
    },
    # REASONING_ENGINE_ID e obrigatorio no codigo (sem default) -- so define
    # a env var quando o modulo do Agent Engine estiver ligado (count = 1),
    # senao o container nem sobe.
    length(module.agent_engine) > 0 ? { REASONING_ENGINE_ID = module.agent_engine[0].reasoning_engine_name } : {}
  )

  secret_env_vars = {
    SMTP_PASSWORD = module.secrets.secret_ids["SMTP_PASSWORD"]
  }

  depends_on = [module.firestore, google_secret_manager_secret_version.smtp_password]
}

# Cloud Tasks distribui as chamadas 1 a 1 pro Cloud Run #2, autenticado via
# OIDC com a service account do Cloud Run #1 (quem enfileira as tasks).
module "fila_disparos" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-tasks-queue?ref=v1.0.0"
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
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
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

  # Nomes tem que bater com os `os.environ.get(...)` lidos em
  # cloud_run/hyper-agent-gatilho-scheduler/main.py. PILOT_WHITELIST fica de
  # fora de proposito (sem default aqui) -- defina como variable separada se
  # quiser popular a whitelist via Terraform; sem ela, ENABLE_WHITELIST=true
  # (default do codigo) bloqueia todo mundo, que e o lado seguro.
  env_vars = {
    PROJECT_ID       = local.project_id
    LOCATION         = "global"
    REGION_TASKS     = local.region
    QUEUE_NAME       = module.fila_disparos.queue_name
    AGENT_ENDPOINT   = module.mensagens_chat.service_url
    SA_EMAIL_INVOKER = local.gatilho_scheduler_sa_email
  }

  depends_on = [module.firestore]
}

module "disparo_10h" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-scheduler-http?ref=v1.0.0"
  project_id = local.project_id
  region     = local.region

  name               = "hyper-agent-disparo-10h"
  schedule           = "0 10 * * *"
  time_zone          = "America/Sao_Paulo"
  uri                = module.gatilho_scheduler.service_url
  service_account_id = "hyper-agent-disparo-10h"
}

module "disparo_14h" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-scheduler-http?ref=v1.0.0"
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

output "agent_engine_staging_bucket" {
  value = length(module.agent_engine) > 0 ? "gs://${module.agent_engine[0].staging_bucket_name}" : "gs://${local.staging_bucket_name}"
}

output "artifact_registry_url" {
  value = module.registry.repository_url
}

output "workload_identity_provider" {
  value = module.github_wif.workload_identity_provider
}

output "deployer_service_account_email" {
  value = module.github_wif.service_account_email
}
