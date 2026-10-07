# Stack aplicado pelo geapp-portal (provision.yml), um state por cliente.
# As variaveis chegam em portal.auto.tfvars.json, escrito pelo workflow a partir
# do input tfvars_json. Valores secretos nunca chegam aqui: o portal grava as
# versoes no Secret Manager antes do dispatch e passa so os nomes.

variable "project_id" {
  description = "Projeto GCP do cliente"
  type        = string
}

variable "client_slug" {
  description = "Slug do cliente no portal; nomeia os recursos"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "secret_env_vars" {
  description = "Env var do Cloud Run => id do secret no Secret Manager do cliente (ja com versao)"
  type        = map(string)
  default     = {}
}

module "registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  location   = var.region
}

module "app" {
  source     = "../../modules/cloud-run"
  project_id = var.project_id
  location   = var.region

  service_name = var.client_slug
  # ID de SA tem no maximo 30 caracteres; o slug vai ate 40.
  service_account_id = "${substr(var.client_slug, 0, 25)}-run"

  service_account_roles = length(var.secret_env_vars) > 0 ? ["roles/secretmanager.secretAccessor"] : []
  secret_env_vars       = var.secret_env_vars
}

output "repository_url" {
  value = module.registry.repository_url
}

output "service_url" {
  value = module.app.service_url
}

output "service_account_email" {
  value = module.app.service_account_email
}
