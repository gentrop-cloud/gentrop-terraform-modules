locals {
  project_id          = "estudos-jean-pereira"
  region              = "us-central1"
  staging_bucket_name = "${local.project_id}-agent-engine-teste-staging"
}

# Sem package_spec: o engine nasce vazio no primeiro apply, junto com o bucket de
# staging, e o CI da aplicacao publica o codigo depois com agent_engines.update.
# O modulo ignora mudancas em spec, entao o apply nao reverte essa publicacao.
module "agent_engine_teste" {
  source     = "../../modules/vertex-ai-agent-engine" # Aponta para a pasta local do módulo
  project_id = local.project_id
  region     = local.region

  display_name        = "agent-engine-teste"
  staging_bucket_name = local.staging_bucket_name

  service_account_roles = [
    "roles/aiplatform.user",
  ]
}

output "reasoning_engine_name" {
  value = module.agent_engine_teste.reasoning_engine_name
}

output "staging_bucket_name" {
  value = module.agent_engine_teste.staging_bucket_name
}
