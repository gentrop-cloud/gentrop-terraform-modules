output "service_url" {
  description = "URL of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.this.name
}

output "service_account_email" {
  description = "Email of the runtime service account used by the service."
  value       = local.service_account_email
}
