module "fila_teste" {
  source     = "../../modules/cloud-tasks-queue" # Aponta para a pasta local do módulo
  project_id = "estudos-jean-pereira"
  location   = "us-central1"

  name = "fila-teste"

  max_dispatches_per_second = 1
  max_concurrent_dispatches = 1
}

output "queue_id" {
  value = module.fila_teste.queue_id
}
