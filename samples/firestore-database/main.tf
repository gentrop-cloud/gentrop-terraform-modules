module "firestore_teste" {
  source     = "../../modules/firestore-database" # Aponta para a pasta local do módulo
  project_id = "estudos-jean-pereira"

  database_id = "firestore-teste"
  location_id = "us-central1"
}

output "database_name" {
  value = module.firestore_teste.name
}
