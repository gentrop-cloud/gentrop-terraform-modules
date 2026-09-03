# workload-identity

Cria o Workload Identity Pool, o provider OIDC do GitHub Actions e (opcionalmente) a
service account que o workflow vai personificar — automatiza os passos manuais do
Console (Habilitar API, Criar Pool, Criar Provider, Criar SA, Conceder Acesso).

## Uso

```hcl
module "github_wif" {
  source     = "../../modules/workload-identity"
  project_id = "seu-projeto-id"

  pool_id     = "github-actions-pool"
  provider_id = "github-oidc-provider"

  # restringe quem pode autenticar (equivalente à "Condição de Atributo" do Console)
  attribute_condition = "attribute.repository.startsWith('gentrop-cloud/')"

  service_account_id     = "github-deployer"
  service_account_roles  = ["roles/run.admin", "roles/storage.admin"]
  github_repositories    = ["gentrop-cloud/genhub", "gentrop-cloud/gentrack"]
}

output "workload_identity_provider" {
  value = module.github_wif.workload_identity_provider
}

output "service_account_email" {
  value = module.github_wif.service_account_email
}
```

## Workflow do GitHub Actions

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ vars.SERVICE_ACCOUNT_EMAIL }}
```

Preencha `WORKLOAD_IDENTITY_PROVIDER` e `SERVICE_ACCOUNT_EMAIL` (variáveis/secrets do
repo ou da org) com os outputs `workload_identity_provider` e `service_account_email`
deste módulo.

## Usando uma service account já existente

```hcl
module "github_wif" {
  source                          = "../../modules/workload-identity"
  project_id                      = "seu-projeto-id"
  create_service_account          = false
  existing_service_account_email  = "ja-existe@seu-projeto-id.iam.gserviceaccount.com"
  github_repositories             = ["gentrop-cloud/genhub"]
}
```

## Notas

- `attribute_mapping` já vem com `google.subject`, `attribute.repository`, `attribute.actor`
  e `attribute.ref`, como recomendado na documentação. Ajuste via variável se precisar de menos/mais.
- O binding de `roles/iam.workloadIdentityUser` é feito por `principalSet://.../attribute.repository/<org>/<repo>`,
  um item de `github_repositories` por repositório — não é preciso descobrir o `project_number` manualmente,
  o módulo usa o nome do pool para montar o principal.
