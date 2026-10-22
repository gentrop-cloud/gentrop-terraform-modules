module "bigquery_teste" {
  source     = "../../modules/bigquery-dataset" # Aponta para a pasta local do módulo
  project_id = "estudos-jean-pereira"

  dataset_id = "bigquery_teste"
  location   = "US"

  tables = {
    exemplo = {
      schema = jsonencode([
        { name = "id", type = "STRING", mode = "REQUIRED" },
        { name = "criado_em", type = "TIMESTAMP", mode = "REQUIRED" },
      ])
    }
  }
}

output "dataset_id" {
  value = module.bigquery_teste.dataset_id
}

output "table_ids" {
  value = module.bigquery_teste.table_ids
}
