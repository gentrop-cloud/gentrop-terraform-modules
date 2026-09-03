# Exemplo: WIF para GitHub Actions

Instancia o modulo [`workload-identity`](../../modules/workload-identity)
no mesmo estilo do `examples/cloud-sql-test`: um `main.tf` só, com os valores
direto no bloco do módulo — exceto o `project_id`, que fica como variável pra
esse mesmo arquivo servir qualquer projeto GCP (a SA sempre sai como
`github-deployer@<project_id>.iam.gserviceaccount.com`).

`service_account_roles` e `github_repositories` continuam fixos em `main.tf` —
ajuste ali se mudar o repositório ou os papéis da SA.

```bash
terraform init
terraform plan -var="project_id=dev-gentrack-0001"
terraform apply -var="project_id=dev-gentrack-0001"
```

Ou crie um `terraform.tfvars` (já é ignorado pelo `.gitignore` do repo) com
`project_id = "dev-gentrack-0001"` e rode `terraform apply` sem `-var`.

Depois do `apply`, use os outputs no workflow do GitHub Actions:

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

No output do ultimo comando, confira o binding `roles/iam.workloadIdentityUser` com
o `principalSet://.../attribute.repository/<org>/<repo>` — se aparecer, o Terraform
aplicou certo.

### 2. Testar a federacao de verdade

Crie no repositorio autorizado (ex: `gentrop-cloud/genhub`) um workflow minimo:

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
sem pedir credencial, a federacao esta funcionando ponta a ponta.

## Provisionamento automatico via commit

Depois que o `terraform apply` acima criar o WIF pela primeira vez (bootstrap manual —
esse primeiro apply nao pode rodar via GitHub Actions porque a identidade ainda nao existe),
os proximos `terraform apply` desse ou de outros projetos podem rodar sozinhos a cada push,
usando os workflows em [`.github/workflows`](../../.github/workflows):

- `terraform-apply.yml` — workflow reutilizavel: recebe `working_directory` e os secrets
  `workload_identity_provider`/`service_account_email`, autentica via WIF e roda `terraform apply`.
- `provision.yml` — dispara em `push` na `main` tocando `examples/**` e chama o workflow acima
  para cada item de uma `matrix`.

Para ligar um projeto GCP a esse pipeline:

1. Crie um **Environment** no GitHub (Settings → Environments) com o nome do projeto,
   ex: `estudos-jean-pereira`.
2. Nesse Environment, adicione os secrets `workload_identity_provider` e
   `service_account_email` com os outputs do `terraform apply` desse projeto.
3. Em `provision.yml`, adicione um item na `matrix` apontando pra pasta do projeto e pro
   Environment criado:

```yaml
- name: outro-projeto
  working_directory: examples/outro-projeto
  environment: outro-projeto-gcp
```

Assim o mesmo workflow serve pra quantos projetos GCP forem adicionados — cada um só
precisa da sua pasta em `examples/` e do seu Environment com os secrets.
