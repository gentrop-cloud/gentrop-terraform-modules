# Deploy dos dois apps pelo Cloud Build do proprio cliente (ADRs 0009 e 0010 do
# geapp-portal), ligado pela opcao enable_cloud_build do portal. Nenhuma conexao
# com o GitHub: o publish-release.yml da main de cada app grava o pacote do commit
# no bucket de releases do seed e publica o sha no topico do app; o trigger de
# Pub/Sub de cada app, aqui, busca o pacote e roda o cloudbuild.yaml dele. O
# provision.yml submete a configuracao destes triggers no fim do apply (primeiro
# deploy, com o pacote latest).
#
# O Terraform e dono dos valores, gravados como substitutions; o cloudbuild.yaml
# de cada app e dono dos nomes das env vars e as aplica no Cloud Run. As
# substitutions abaixo tem que bater uma a uma com as usadas no cloudbuild.yaml
# (mais _SOURCE e _SHA, que o trigger acrescenta): o Cloud Build recusa
# substitution faltando ou sobrando.

resource "google_project_service" "cloudbuild" {
  count = local.cloud_build ? 1 : 0

  project            = var.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# SA propria do deploy, no lugar da SA padrao do Cloud Build (que em projetos
# novos nem e mais a padrao dos builds). Le os pacotes do bucket de releases pela
# permissao da pasta de clientes (bootstrap).
resource "google_service_account" "deployer" {
  count = local.cloud_build ? 1 : 0

  project      = var.project_id
  account_id   = "cloud-build-deployer"
  display_name = "Deploy do app pelo Cloud Build"

  depends_on = [google_project_service.cloudbuild]
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
    "roles/cloudbuild.builds.editor",     # o trigger submete o build do app
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

resource "google_cloudbuild_trigger" "deploy" {
  for_each = local.cloud_build ? local.release_apps : {}

  project         = var.project_id
  location        = var.region
  name            = each.value.trigger
  service_account = google_service_account.deployer[0].id

  # Criar a assinatura num topico do seed exige pubsub.subscriber do service agent
  # do Cloud Build deste projeto nele, dado pelo stack project.
  pubsub_config {
    topic = var.release_topics[each.key]
  }

  substitutions = merge(each.value.substitutions, {
    _SHA = "$(body.message.attributes.sha)"
  })

  # So busca o codigo e delega: o build do app roda --no-source, porque o gcloud
  # builds submit com codigo em gs:// passa pelo bucket de staging do projeto e
  # recusa a cloud-build-deployer. O primeiro passo do cloudbuild.yaml do app
  # extrai $_SOURCE.
  build {
    timeout = "3600s"

    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk:slim"
      entrypoint = "bash"
      args = ["-ec", <<-EOT
        sha="$${_SHA}"
        # Sem mensagem (primeiro deploy pelo provision.yml), o ultimo pacote da main.
        case "$$sha" in ""|*body.message*) sha=$$(gcloud storage cat gs://${var.release_bucket}/${each.key}/latest) ;; esac
        src="gs://${var.release_bucket}/${each.key}/$$sha.tar.gz"
        echo "Pacote: $$src"
        gcloud storage cat "$$src" | tar -xzO -f - cloudbuild.yaml > /workspace/cloudbuild.yaml
        id=$$(gcloud builds submit --no-source --config=/workspace/cloudbuild.yaml --region=${var.region} \
          --service-account=${google_service_account.deployer[0].id} \
          --substitutions="^|^_SOURCE=$$src|_SHA=$$sha|${each.value.passthrough}" \
          --async --format='value(id)')
        echo "Build do app: $$id"
        # --async e espera aqui: sem roles/viewer o gcloud nao acompanha o log do build.
        while :; do
          status=$$(gcloud builds describe "$$id" --region=${var.region} --format='value(status)')
          case "$$status" in
            QUEUED|PENDING|WORKING) sleep 15 ;;
            SUCCESS) exit 0 ;;
            *) echo "Build do app $$id terminou com $$status"; exit 1 ;;
          esac
        done
      EOT
      ]
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  depends_on = [google_project_iam_member.deployer, google_storage_bucket_iam_member.deployer_staging]
}

locals {
  cloud_build = var.enable_cloud_build

  # Formato do gcloud run deploy --set-secrets (ENV=SECRET:latest,...): so os
  # nomes que o portal mandou, nunca valores (ADR 0005 do geapp-portal).
  app_secret_env  = join(",", [for k, v in var.secret_env_vars : "${k}=${v}:latest" if contains(local.app_secret_names, k)])
  chat_secret_env = join(",", [for k, v in var.secret_env_vars : "${k}=${v}:latest" if k == "SMTP_PASSWORD"])

  # Chave = pasta no bucket de releases e chave em var.release_topics.
  release_app_substitutions = {
    # Usadas no cloudbuild.yaml do gemini-enteprise-adoption-portal.
    geapp = {
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
    # Usadas no cloudbuild.yaml do hyper-agent.
    hyper-agent = {
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
  }

  release_apps = {
    for app, subs in local.release_app_substitutions : app => {
      trigger       = app == "geapp" ? "deploy-app" : "deploy-${app}"
      substitutions = subs
      # Repassa cada substitution ao build do app: _X=${_X}, separadas por "|"
      # porque _SECRET_ENV tem virgulas.
      passthrough = join("|", [for k in keys(subs) : format("%s=$${%s}", k, k)])
    }
  }
}
