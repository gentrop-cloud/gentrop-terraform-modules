locals {
  service_account_email = var.create_service_account ? google_service_account.this[0].email : var.existing_service_account_email
}

resource "google_project_service" "this" {
  for_each = var.enable_apis ? toset(["aiplatform.googleapis.com", "storage.googleapis.com"]) : []

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "this" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
}

resource "google_project_iam_member" "sa_roles" {
  for_each = toset(var.service_account_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.service_account_email}"
}

resource "google_storage_bucket" "staging" {
  project                     = var.project_id
  name                        = var.staging_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true

  depends_on = [google_project_service.this]
}

resource "google_vertex_ai_reasoning_engine" "this" {
  # Desligado no primeiro apply: o bucket de staging precisa existir antes, pro CI
  # da aplicacao subir o bundle que o Vertex AI valida na criacao do recurso.
  count = var.create_reasoning_engine ? 1 : 0

  project      = var.project_id
  region       = var.region
  display_name = var.display_name
  description  = var.description

  spec {
    service_account = local.service_account_email

    # Sem package_spec o engine nasce vazio e o CI da aplicacao publica o codigo
    # depois (agent_engines.update); com ele, o bundle ja precisa estar no GCS.
    dynamic "package_spec" {
      for_each = var.package_spec == null ? [] : [var.package_spec]
      content {
        pickle_object_gcs_uri    = package_spec.value.pickle_object_gcs_uri
        requirements_gcs_uri     = package_spec.value.requirements_gcs_uri
        dependency_files_gcs_uri = package_spec.value.dependency_files_gcs_uri
        python_version           = package_spec.value.python_version
      }
    }
  }

  # O build/upload do bundle (pickle + requirements) e feito pelo CI da
  # aplicacao via Vertex AI SDK, fora deste Terraform; sem isso o apply
  # reverteria o agente pra versao antiga a cada novo deploy do CI. Mesmo
  # padrao usado para a imagem no modulo cloud-run.
  lifecycle {
    ignore_changes = [spec]
  }

  depends_on = [google_project_service.this, google_project_iam_member.sa_roles]
}

# Estados aplicados antes do count acima: evita recriar o Agent Engine.
moved {
  from = google_vertex_ai_reasoning_engine.this
  to   = google_vertex_ai_reasoning_engine.this[0]
}
