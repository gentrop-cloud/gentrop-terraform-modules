locals {
  required_services = [
    "sqladmin.googleapis.com",
    "iam.googleapis.com"
  ]
}

resource "google_project_service" "gcp_services" {
  for_each           = toset(local.required_services)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false 
}