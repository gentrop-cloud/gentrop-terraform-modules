# Exemplo: WIF para GitHub Actions

Instancia o módulo [`workload-identity`](../../modules/workload-identity): cria o
Workload Identity Pool, o provider OIDC do GitHub Actions e a service account
`github-deployer@<project_id>.iam.gserviceaccount.com`.

## Como usar

1. Abra o `main.tf` e ajuste `project_id`. `service_account_roles` e
   `github_repositories` também ficam fixos ali — troque se mudar o repositório ou
   os papéis da SA.
2. Conecte com esse projeto via `gcloud`:
   ```bash
   gcloud auth application-default login
   gcloud config set project SEU_PROJETO_ID
   ```
3. ```bash
   terraform init
   ```
4. ```bash
   terraform apply -var="project_id=SEU_PROJETO_ID"
   ```
   (ou crie um `terraform.tfvars` com `project_id = "SEU_PROJETO_ID"` e rode
   `terraform apply` sem `-var`)
5. Se aplicou no projeto errado:
   ```bash
   terraform destroy -var="project_id=SEU_PROJETO_ID"
   ```

Depois do apply, pegue os outputs pro workflow do GitHub Actions:

```bash
terraform output workload_identity_provider
terraform output service_account_email
```

## Como testar

Duas partes: validar o que o Terraform criou no GCP (100% local) e validar a
federação de fato (só funciona dentro de um runner do GitHub Actions, que é
quem emite o token OIDC).

### 1. Validar o lado do Google Cloud

```bash
gcloud iam workload-identity-pools describe github-actions-pool --location=global --project=SEU_PROJECT_ID
```

```bash
gcloud iam workload-identity-pools providers describe github-oidc-provider --workload-identity-pool=github-actions-pool --location=global --project=SEU_PROJECT_ID
```

```bash
gcloud iam service-accounts get-iam-policy SEU_SA_EMAIL --project=SEU_PROJECT_ID
```

No output do último comando, confira o binding `roles/iam.workloadIdentityUser` com
o `principalSet://.../attribute.repository/<org>/<repo>` — se aparecer, o Terraform
aplicou certo.

### 2. Testar a federação de verdade

Crie no repositório autorizado (ex: `gentrop-cloud/genhub`) um workflow mínimo:

```yaml
# .github/workflows/test-wif.yml
name: test-wif
on: workflow_dispatch

permissions:
  contents: read
  id-token: write

jobs:
  auth:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: "SEU_WORKLOAD_IDENTITY_PROVIDER"
          service_account: "SEU_SA_EMAIL"
      - run: gcloud auth list
      - run: gcloud projects describe SEU_PROJECT_ID
```

Dispare e acompanhe pelo terminal com `gh` (precisa de `gh auth login` feito antes):

```bash
gh workflow run test-wif.yml --repo gentrop-cloud/genhub
```

```bash
gh run watch --repo gentrop-cloud/genhub
```

Se `gcloud auth list` mostrar a service account e `gcloud projects describe` funcionar
sem pedir credencial, a federação está funcionando ponta a ponta.
