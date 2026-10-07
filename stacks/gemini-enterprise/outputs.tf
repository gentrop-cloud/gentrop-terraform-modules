output "mensagens_chat_url" {
  value = module.mensagens_chat.service_url
}

output "gatilho_scheduler_url" {
  value = module.gatilho_scheduler.service_url
}

output "artifact_registry_url" {
  value = module.registry.repository_url
}

output "agent_engine_staging_bucket" {
  value = "gs://${module.agent_engine.staging_bucket_name}"
}

output "reasoning_engine_name" {
  value = module.agent_engine.reasoning_engine_name
}

output "firestore_database" {
  value = module.firestore.name
}

output "bigquery_dataset" {
  value = module.auditoria.dataset_id
}

output "app_url" {
  description = "URL do app GE (NEXTAUTH_URL); o redirect da credencial OAuth e <app_url>/api/auth/callback/google"
  value       = local.app_url
}

output "app_service_account" {
  value = google_service_account.app.email
}

output "app_image_registry" {
  value = "${module.app_registry.repository_url}/app"
}

output "db_instance_connection_name" {
  value = module.db.instance_connection_name
}

output "cloud_build_trigger" {
  value = one(google_cloudbuild_trigger.deploy_app[*].name)
}
