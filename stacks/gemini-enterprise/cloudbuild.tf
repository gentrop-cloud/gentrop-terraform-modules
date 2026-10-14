# Deploy dos dois apps pelo Cloud Build do proprio cliente (ADR 0009 do
# geapp-portal), ligado pela opcao enable_cloud_build do portal: conexao de 2a
# geracao com o GitHub, link dos repos e um trigger por app em push na main.
# O provision.yml roda os mesmos triggers no fim do apply (primeiro deploy).
#
# O Terraform e dono dos valores, gravados como substitutions; o cloudbuild.yaml
# de cada app e dono dos nomes das env vars e as aplica no Cloud Run. As
# substitutions abaixo tem que bater uma a uma com as usadas no cloudbuild.yaml:
# o Cloud Build recusa substitution faltando ou sobrando.

resource "google_project_service" "cloudbuild" {
  count = local.cloud_build ? 1 : 0

  project            = var.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# O service agent do Cloud Build so existe depois da API ligada; este recurso
# garante que ele foi criado antes de receber acesso ao token.
resource "google_project_service_identity" "cloudbuild" {
  count = local.cloud_build ? 1 : 0

  provider = google-beta
  project  = var.project_id
  service  = "cloudbuild.googleapis.com"

  depends_on = [google_project_service.cloudbuild]
}

# O token do GitHub mora num secret unico no projeto de controle; cada cliente
# so recebe permissao de leitura nele para o service agent do Cloud Build.
resource "google_secret_manager_secret_iam_member" "github_token" {
  count = local.cloud_build ? 1 : 0

  secret_id = var.github_token_secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_project_service_identity.cloudbuild[0].email}"
}

resource "google_cloudbuildv2_connection" "github" {
  count = local.cloud_build ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = "github"

  github_config {
    app_installation_id = tonumber(var.github_app_installation_id)
    authorizer_credential {
      oauth_token_secret_version = "${var.github_token_secret}/versions/latest"
    }
  }

  lifecycle {
    precondition {
      condition     = var.github_app_installation_id != "" && var.github_token_secret != ""
      error_message = "enable_cloud_build exige as vars CLOUDBUILD_GITHUB_INSTALLATION_ID e CLOUDBUILD_GITHUB_TOKEN_SECRET no repo."
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.github_token]
}

resource "google_cloudbuildv2_repository" "app" {
  count = local.cloud_build ? 1 : 0

  project           = var.project_id
  location          = var.region
  name              = "gemini-enteprise-adoption-portal"
  parent_connection = google_cloudbuildv2_connection.github[0].name
  remote_uri        = var.app_repository
}

resource "google_cloudbuildv2_repository" "hyper_agent" {
  count = local.cloud_build ? 1 : 0

  project           = var.project_id
  location          = var.region
  name              = "hyper-agent"
  parent_connection = google_cloudbuildv2_connection.github[0].name
  remote_uri        = var.hyper_agent_repository
}

# SA propria do deploy, no lugar da SA padrao do Cloud Build (que em projetos
# novos nem e mais a padrao dos builds).
resource "google_service_account" "deployer" {
  count = local.cloud_build ? 1 : 0

  project      = var.project_id
  account_id   = "cloud-build-deployer"
  display_name = "Deploy do app pelo Cloud Build"
}

resource "google_project_iam_member" "deployer" {
  for_each = local.cloud_build ? toset([
    "roles/run.admin",                    # deploy no Cloud Run
    "roles/iam.serviceAccountUser",       # anexar a SA de runtime ao servico
    "roles/secretmanager.secretAccessor", # ler os secrets no build
    "roles/cloudsql.client",              # cloud-sql-proxy nas migracoes
    "roles/artifactregistry.writer",      # push da imagem
    "roles/logging.logWriter",            # logs do build (CLOUD_LOGGING_ONLY)
    "roles/aiplatform.user",              # hyper-agent: publicar o Agent Engine
  ]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer[0].email}"
}

# O proxy das migracoes age como a SA do app (dona das tabelas).
resource "google_service_account_iam_member" "deployer_impersonates_app" {
  count = local.cloud_build ? 1 : 0

  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.deployer[0].email}"
}

# O deploy do Agent Engine sobe o pacote do agente no bucket de staging.
resource "google_storage_bucket_iam_member" "deployer_staging" {
  count = local.cloud_build ? 1 : 0

  bucket = module.agent_engine.staging_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.deployer[0].email}"
}

resource "google_cloudbuild_trigger" "deploy_app" {
  count = local.cloud_build ? 1 : 0

  project         = var.project_id
  location        = var.region
  name            = "deploy-app"
  filename        = "cloudbuild.yaml"
  service_account = google_service_account.deployer[0].id

  repository_event_config {
    repository = google_cloudbuildv2_repository.app[0].id
    push {
      branch = var.app_branch
    }
  }

  # Usadas no cloudbuild.yaml do gemini-enteprise-adoption-portal.
  substitutions = {
    _SERVICE_ACCOUNT                    = google_service_account.app.email
    _CLOUD_SQL_DB_NAME                  = module.db.database_name
    _CLOUD_SQL_DB_USER                  = local.app_db_user
    _CLOUD_SQL_DB_USER_ENCODED          = urlencode(local.app_db_user)
    _CLOUD_SQL_INSTANCE_CONNECTION_NAME = module.db.instance_connection_name
    _IMAGE_ARTIFACT_REGISTRY            = module.app_registry.repository_url
    _SERVICE_NAME_CLIENT                = local.app_service_name
    _NEXTAUTH_URL                       = local.app_url
    _GOOGLE_CLIENT_ID                   = var.google_client_id
    _GCP_PROJECT_REGION                 = var.region
    _AGENT_REASONING_ENGINE_NAME        = module.agent_engine.reasoning_engine_name
    _FIRESTORE_DB_ID                    = local.firestore_database_id
    _GENGUIDE_PROJECT_ID                = var.genguide_project_id
    _BIGQUERY_DATASET_ID                = module.atividade_ge.dataset_id
    _SECRET_ENV                         = local.app_secret_env
  }

  depends_on = [google_project_iam_member.deployer]
}

resource "google_cloudbuild_trigger" "deploy_hyper_agent" {
  count = local.cloud_build ? 1 : 0

  project         = var.project_id
  location        = var.region
  name            = "deploy-hyper-agent"
  filename        = "cloudbuild.yaml"
  service_account = google_service_account.deployer[0].id

  repository_event_config {
    repository = google_cloudbuildv2_repository.hyper_agent[0].id
    push {
      branch = var.app_branch
    }
  }

  # Usadas no cloudbuild.yaml do hyper-agent.
  substitutions = {
    _GCP_PROJECT_REGION          = var.region
    _AGENT_STAGING_BUCKET        = "gs://${module.agent_engine.staging_bucket_name}"
    _AGENT_REASONING_ENGINE_NAME = module.agent_engine.reasoning_engine_name
    _VERTEX_DATASTORE_ID         = google_discovery_engine_data_store.engajamento.data_store_id
    _FIRESTORE_DB_ID             = local.firestore_database_id
    _IMAGE_ARTIFACT_REGISTRY     = module.app_registry.repository_url
    _QUEUE_NAME                  = module.fila_disparos.queue_name
    _AGENT_ENDPOINT              = module.mensagens_chat.service_url
    _SA_EMAIL_INVOKER            = local.gatilho_scheduler_sa_email
    _SMTP_EMAIL                  = var.smtp_email
    _CHAT_SECRET_ENV             = local.chat_secret_env
  }

  depends_on = [google_project_iam_member.deployer, google_storage_bucket_iam_member.deployer_staging]
}

locals {
  cloud_build = var.enable_cloud_build

  # Formato do gcloud run deploy --set-secrets (ENV=SECRET:latest,...): so os
  # nomes que o portal mandou, nunca valores (ADR 0005 do geapp-portal).
  app_secret_env  = join(",", [for k, v in var.secret_env_vars : "${k}=${v}:latest" if contains(local.app_secret_names, k)])
  chat_secret_env = join(",", [for k, v in var.secret_env_vars : "${k}=${v}:latest" if k == "SMTP_PASSWORD"])
}
