resource "google_project_service" "this" {
  for_each = var.enable_apis ? toset(["firestore.googleapis.com"]) : []

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_firestore_database" "this" {
  project     = var.project_id
  name        = var.database_id
  location_id = var.location_id
  type        = "FIRESTORE_NATIVE"

  delete_protection_state           = var.delete_protection_state
  point_in_time_recovery_enablement = var.point_in_time_recovery_enablement

  depends_on = [google_project_service.this]
}
