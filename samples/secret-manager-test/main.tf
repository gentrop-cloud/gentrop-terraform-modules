module "secrets_teste" {
  source     = "../../modules/secret-manager" # Aponta para a pasta local do módulo
  project_id = "estudos-jean-pereira"

  secret_ids = [
    "NEXTAUTH_SECRET",
    "GOOGLE_CLIENT_SECRET",
    "DATABASE_URL",
    "DIRECT_URL",
  ]
}

output "secret_ids" {
  value = module.secrets_teste.secret_ids
}
