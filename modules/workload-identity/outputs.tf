output "workload_identity_provider" {
  description = "Full resource name to use as workload_identity_provider in google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Email of the service account to use as service_account in google-github-actions/auth."
  value       = local.service_account_email
}

output "workload_identity_pool_id" {
  description = "Workload Identity Pool id."
  value       = google_iam_workload_identity_pool.this.workload_identity_pool_id
}
