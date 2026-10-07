resource "google_project_service" "this" {
  for_each = var.enable_apis ? toset(["artifactregistry.googleapis.com"]) : []

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = var.format

  depends_on = [google_project_service.this]
}
