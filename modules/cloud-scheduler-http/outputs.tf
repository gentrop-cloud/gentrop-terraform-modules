output "service_account_email" {
  description = "Email of the service account used for the OIDC token — grant it roles/run.invoker (or equivalent) on the target."
  value       = local.service_account_email
}

output "job_name" {
  description = "Cloud Scheduler job name."
  value       = google_cloud_scheduler_job.this.name
}
