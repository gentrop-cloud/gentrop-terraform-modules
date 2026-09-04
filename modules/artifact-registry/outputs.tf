output "repository_id" {
  description = "Repository id."
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Full resource name of the repository."
  value       = google_artifact_registry_repository.this.name
}

output "repository_url" {
  description = "Registry host/path to use as image prefix, e.g. \"<url>/<image>:<tag>\"."
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
