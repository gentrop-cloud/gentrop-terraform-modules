resource "google_project_service" "this" {
  for_each = var.enable_apis ? toset(["cloudtasks.googleapis.com"]) : []

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_cloud_tasks_queue" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location

  rate_limits {
    max_dispatches_per_second = var.max_dispatches_per_second
    max_concurrent_dispatches = var.max_concurrent_dispatches
  }

  retry_config {
    max_attempts = var.max_attempts
  }

  depends_on = [google_project_service.this]
}

resource "google_cloud_tasks_queue_iam_member" "enqueuer" {
  for_each = toset(var.enqueuer_members)

  project  = var.project_id
  location = var.location
  name     = google_cloud_tasks_queue.this.name
  role     = "roles/cloudtasks.enqueuer"
  member   = each.value
}
