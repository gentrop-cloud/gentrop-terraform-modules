module "cloud_run_teste" {
  source     = "../../modules/cloud-run" # Aponta para a pasta local do módulo
  project_id = "estudos-jean-pereira"

  service_name = "cloud-run-teste"
  # sem image/secret_env_vars: usa a imagem publica default so pra validar o modulo isolado
}

output "service_url" {
  value = module.cloud_run_teste.service_url
}
