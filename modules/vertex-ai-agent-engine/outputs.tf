output "reasoning_engine_name" {
  description = "Full resource name (projects/PROJECT/locations/REGION/reasoningEngines/ID); null while create_reasoning_engine is false."
  value       = one(google_vertex_ai_reasoning_engine.this[*].name)
}

output "service_account_email" {
  description = "Email of the runtime service account used by the reasoning engine."
  value       = local.service_account_email
}

output "staging_bucket_name" {
  description = "Name of the GCS staging bucket."
  value       = google_storage_bucket.staging.name
}
