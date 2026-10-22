module "scheduler_teste" {
  source     = "../../modules/cloud-scheduler-http" # Aponta para a pasta local do módulo
  project_id = "estudos-jean-pereira"
  region     = "us-central1"

  name      = "scheduler-teste"
  schedule  = "0 10 * * *"
  time_zone = "America/Sao_Paulo"
  uri       = "https://example.com" # troque pela URL real (ex: Cloud Run) antes de aplicar
}

output "service_account_email" {
  value = module.scheduler_teste.service_account_email
}
