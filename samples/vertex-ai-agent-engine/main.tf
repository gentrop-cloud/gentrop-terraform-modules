locals {
  project_id          = "estudos-jean-pereira"
  region              = "us-central1"
  staging_bucket_name = "${local.project_id}-agent-engine-teste-staging"
}

module "agent_engine_teste" {
  # count = 0 cria so a service account + bucket + habilitacao de API.
  # O Vertex AI valida e copia os objetos do GCS na hora de criar o
  # Reasoning Engine, entao so mude pra count = 1 depois de confirmar que
  # agent.pkl e requirements.txt existem de verdade no bucket abaixo (veja o
  # README desta pasta).
  count = 0

  source     = "../../modules/vertex-ai-agent-engine" # Aponta para a pasta local do módulo
  project_id = local.project_id
  region     = local.region

  display_name        = "agent-engine-teste"
  staging_bucket_name = local.staging_bucket_name

  service_account_roles = [
    "roles/aiplatform.user",
  ]

  package_spec = {
    pickle_object_gcs_uri = "gs://${local.staging_bucket_name}/agent.pkl"
    requirements_gcs_uri  = "gs://${local.staging_bucket_name}/requirements.txt"
  }
}

output "reasoning_engine_name" {
  value = length(module.agent_engine_teste) > 0 ? module.agent_engine_teste[0].reasoning_engine_name : null
}

output "staging_bucket_name" {
  value = length(module.agent_engine_teste) > 0 ? module.agent_engine_teste[0].staging_bucket_name : local.staging_bucket_name
}
