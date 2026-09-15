# cloud-run

Cria um serviço no Cloud Run (v2), com service account de runtime própria e
suporte a env vars comuns e a secrets do Secret Manager.

## Uso

```hcl
module "app" {
  source     = "../../modules/cloud-run"
  project_id = "seu-projeto-id"
  service_name = "gentrack"

  service_account_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/cloudsql.client",
  ]

  env_vars = {
    GOOGLE_CLIENT_ID = "xxxx.apps.googleusercontent.com"
  }

  secret_env_vars = {
    NEXTAUTH_SECRET       = "NEXTAUTH_SECRET"
    GOOGLE_CLIENT_SECRET  = "GOOGLE_CLIENT_SECRET"
    DATABASE_URL          = "DATABASE_URL"
    DIRECT_URL            = "DIRECT_URL"
  }
}
```

Os valores de `secret_env_vars` são os `secret_id` criados pelo módulo
`secret-manager` (não a versão nem o resource name completo) — o serviço
sempre lê a version `latest`.

## Cloud SQL

Passe `cloudsql_connection_name` (o `instance_connection_name` do módulo
`cloud-sql-postgress`) para montar o Cloud SQL Auth Proxy em `/cloudsql` —
conecta pelo socket, sem precisar de IP público autorizado nem VPC connector.
A `DATABASE_URL` fica algo como:
`postgresql://usuario:senha@localhost/banco?host=/cloudsql/PROJECT:REGION:INSTANCE`.

## Imagem e CD

`image` só define a imagem usada no primeiro apply. O módulo ignora mudanças
nesse campo depois (`lifecycle.ignore_changes`), então o pipeline de CD pode
fazer deploy de novas imagens (via `gcloud run deploy` ou API) sem o Terraform
reverter para a imagem antiga na próxima vez que rodar. Por outro lado, mudar
`env_vars`/`secret_env_vars` e rodar `terraform apply` cria uma nova revision
usando a imagem atual — não depende do step de CD para isso.

## Invocação autenticada (OIDC)

Além de `allow_unauthenticated` (acesso público via `allUsers`), passe
`invoker_members` para conceder `roles/run.invoker` a chamadores específicos
autenticados via OIDC — por exemplo a service account de um job do
`cloud-scheduler-http` ou de uma fila do `cloud-tasks-queue`:

```hcl
invoker_members = [
  "serviceAccount:${module.disparo_10h.service_account_email}",
]
```

Para tarefas do Cloud Tasks: a service account usada no OIDC token de cada
task é definida pela aplicação no momento de criar a task (não é uma
propriedade da fila em si) — normalmente a mesma runtime SA do serviço que
enfileira. Adicione essa SA em `invoker_members` do Cloud Run que consome a
fila.
