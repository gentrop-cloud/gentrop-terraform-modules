locals {
  service_account_email = var.create_service_account ? google_service_account.this[0].email : var.existing_service_account_email
}

resource "google_project_service" "this" {
  for_each = var.enable_apis ? toset(["cloudscheduler.googleapis.com"]) : []

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

resource "google_cloud_scheduler_job" "this" {
  project     = var.project_id
  region      = var.region
  name        = var.name
  description = var.description
  schedule    = var.schedule
  time_zone   = var.time_zone

  http_target {
    uri         = var.uri
    http_method = var.http_method
    body        = var.body != null ? base64encode(var.body) : null
    headers     = var.headers

    oidc_token {
      service_account_email = local.service_account_email
      # Explicito: sem ele o Scheduler grava a URL com "/" no fim e todo plan
      # mostra um diff para voltar a null. O Cloud Run aceita a URL do servico.
      audience = "${trimsuffix(var.uri, "/")}/"
    }
  }

  depends_on = [google_project_service.this]
}
