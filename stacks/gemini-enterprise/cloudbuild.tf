# Desligado por padrao (enable_cloud_build): o fluxo de deploy ainda vai ser
# definido. Ligado, faz o deploy do app pelo Cloud Build do proprio cliente: conexao de 2a geracao com
# o GitHub, link do repo e trigger em push na branch do app.
#
# O cloudbuild.yaml do app precisa:
# - ter `options: logging: CLOUD_LOGGING_ONLY` (trigger com SA propria);
# - rodar o cloud-sql-proxy com --auto-iam-authn e
#   --impersonate-service-account=$_APP_SERVICE_ACCOUNT nas migracoes;
# - criar/atualizar o Cloud Run $_SERVICE_NAME_CLIENT com --service-account
#   $_APP_SERVICE_ACCOUNT, --add-cloudsql-instances $_INSTANCE_CONNECTION_NAME e
#   os secrets NEXTAUTH_SECRET / GOOGLE_CLIENT_SECRET do Secret Manager.

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

  substitutions = {
    _DB_USER                  = local.app_db_user
    _DB_USER_ENCODED          = urlencode(local.app_db_user)
    _DB_NAME                  = module.db.database_name
    _INSTANCE_CONNECTION_NAME = module.db.instance_connection_name
    _IMAGE_REGISTRY           = "${module.app_registry.repository_url}/app"
    _SERVICE_NAME_CLIENT      = local.app_service_name
    _APP_SERVICE_ACCOUNT      = google_service_account.app.email
    _NEXTAUTH_URL             = local.app_url
    _GOOGLE_CLIENT_ID         = var.google_client_id
    _AGENT_PROJECT_ID         = var.project_id
    _LOCATION                 = var.region
    _RESOURCE_ID              = module.agent_engine.reasoning_engine_name != null ? module.agent_engine.reasoning_engine_name : ""
  }

  depends_on = [google_project_iam_member.deployer]
}

locals {
  cloud_build = var.enable_cloud_build
}
