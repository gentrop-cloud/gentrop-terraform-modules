module "banco_teste" {
  source = "../../modules/cloud-sql-postgress" # Aponta para a pasta local do módulo

  project_id        = "estudos-jean-pereira"
  instance_name     = "instancia-teste-db-module"
  database_name     = "portal_teste"
  region            = "us-central1"
  db_tier           = "db-f1-micro"
  db_admin_password = ",6U0zj0:K3(%"

  authorized_networks = [
    {
      name  = "meu-wsl-local"
      value = "179.48.89.219/32" # Ex: 177.100.200.50/32
    }
  ]
}