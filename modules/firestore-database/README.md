# firestore-database

Cria um banco Firestore em modo Native.

## Uso

```hcl
module "db" {
  source      = "../../modules/firestore-database"
  project_id  = "seu-projeto-id"
  database_id = "hyper-project-db-native"
  location_id = "us-central1"
}
```

Acesso de leitura/escrita para um serviço (ex: Cloud Run) é concedido via
`roles/datastore.user` na lista `service_account_roles` do módulo `cloud-run`
— este módulo não cria nenhum binding de IAM próprio.

Índices compostos não são criados por este módulo; adicione
`google_firestore_index` separadamente se/quando uma query realmente precisar.
