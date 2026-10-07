# cloud-tasks-queue

Cria uma fila de Cloud Tasks com rate limiting/retry, e concede
`roles/cloudtasks.enqueuer` a quem precisa enfileirar tarefas.

## Uso

```hcl
module "fila_disparos" {
  source     = "../../modules/cloud-tasks-queue"
  project_id = "seu-projeto-id"
  location   = "us-central1"
  name       = "fila-disparos-hyperproject"

  max_dispatches_per_second = 1
  max_concurrent_dispatches = 1

  enqueuer_members = [
    "serviceAccount:${module.hyper_agent_gatilho.service_account_email}",
  ]
}
```

Quem *consome* a fila (o alvo HTTP dos tasks, via OIDC) não é configurado
aqui — isso é `invoker_members` no módulo `cloud-run` do serviço de destino.
