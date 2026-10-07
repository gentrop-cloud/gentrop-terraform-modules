# secret-manager

Cria os containers dos secrets no Secret Manager (sem version/valor) — os
valores são populados depois, manualmente (`gcloud secrets versions add` /
Console) ou pelo pipeline de CD. Evita colocar segredos como
`GOOGLE_CLIENT_SECRET` ou `DATABASE_URL` em texto no `.tf` ou no state do
Terraform.

## Uso

```hcl
module "secrets" {
  source     = "../../modules/secret-manager"
  project_id = "seu-projeto-id"

  secret_ids = [
    "NEXTAUTH_SECRET",
    "GOOGLE_CLIENT_SECRET",
    "DATABASE_URL",
    "DIRECT_URL",
  ]
}
```

Os IDs em `secret_ids` (ex: `"DATABASE_URL"`) são o que o módulo `cloud-run`
espera em `secret_env_vars` para montar o `secret_key_ref`.
