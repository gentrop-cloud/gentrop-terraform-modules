resource "google_project_service" "this" {
  for_each = var.enable_apis ? toset(["bigquery.googleapis.com"]) : []

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_bigquery_dataset" "this" {
  project    = var.project_id
  dataset_id = var.dataset_id
  location   = var.location

  depends_on = [google_project_service.this]
}

resource "google_bigquery_table" "this" {
  for_each = var.tables

  project    = var.project_id
  dataset_id = google_bigquery_dataset.this.dataset_id
  table_id   = each.key
  schema     = each.value.schema

  deletion_protection = each.value.deletion_protection
}
