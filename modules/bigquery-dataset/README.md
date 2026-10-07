# bigquery-dataset

Cria um dataset BigQuery e, opcionalmente, tabelas dentro dele.

## Uso

```hcl
module "auditoria" {
  source     = "../../modules/bigquery-dataset"
  project_id = "seu-projeto-id"
  dataset_id = "hyper_agent_auditoria"
  location   = "us-central1"

  tables = {
    eventos = {
      schema = jsonencode([
        { name = "user_email", type = "STRING", mode = "REQUIRED" },
        { name = "evento", type = "STRING", mode = "REQUIRED" },
        { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
      ])
    }
  }
}
```

Acesso é concedido via `roles/bigquery.dataEditor` (ou outro role do BigQuery)
na lista `service_account_roles` do módulo `cloud-run` — este módulo não cria
nenhum binding de IAM próprio.
