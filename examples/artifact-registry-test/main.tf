module "registry_teste" {
  source     = "../../modules/artifact-registry" # Aponta para a pasta local do módulo
  project_id = "estudos-jean-pereira"
}

output "repository_url" {
  value = module.registry_teste.repository_url
}
