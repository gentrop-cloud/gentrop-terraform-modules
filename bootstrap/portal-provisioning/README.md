# Bootstrap do provisionamento via portal

Duas contas, cada uma com uma responsabilidade:

| Conta | Onde mora | O que faz |
| --- | --- | --- |
| `geapp-seed-sa` | só no `geapp-prod-seed-0001` | cria o projeto do cliente e, dentro dele, a `tf-provisioner` (`stacks/project`) |
| `tf-provisioner` | uma em cada projeto de cliente | provisiona os serviços do próprio projeto (demais stacks) |

O `provision.yml` escolhe a conta pelo stack: `project` roda como a
`geapp-seed-sa`; os demais, como `tf-provisioner@<project_id>`. O seed não é
projeto de cliente nem de prod.

## 1. Papéis concedidos pelo admin da org

Só para a `geapp-seed-sa`, fora deste Terraform, porque exigem acesso à pasta e
ao faturamento:

- na **pasta de clientes**: `roles/resourcemanager.projectCreator`;
- na **conta de faturamento** dos clientes: `roles/billing.user`.

Os papéis da `tf-provisioner` não passam pelo admin: o stack `project` concede no
próprio projeto (`tf_provisioner_roles` em `stacks/project/main.tf`).

## 2. Aplicar este root

Por quem tem Owner no seed. Cria o WIF do GitHub no seed, dá à `geapp-seed-sa`
acesso ao bucket de state e habilita as APIs no seed.

```bash
gcloud auth application-default login
terraform init
terraform apply
```

Depois, configure o repositório com os outputs:

```bash
gh variable set WIF_PROVIDER      --repo gentrop-cloud/gentrop-terraform-modules --body "$(terraform output -raw workload_identity_provider)"
gh variable set SEED_SA_EMAIL     --repo gentrop-cloud/gentrop-terraform-modules --body "$(terraform output -raw service_account_email)"
gh variable set TF_STATE_BUCKET   --repo gentrop-cloud/gentrop-terraform-modules --body "gentrop-tfstate"
gh variable set PORTAL_URL        --repo gentrop-cloud/gentrop-terraform-modules --body "https://<url pública do portal>"
gh variable set PORTAL_SA_EMAIL   --repo gentrop-cloud/gentrop-terraform-modules --body "<SA de runtime do geapp-portal>"
gh variable set CLIENTS_FOLDER_ID --repo gentrop-cloud/gentrop-terraform-modules --body "<id da pasta de clientes>"
gh variable set CLOUDBUILD_GITHUB_TOKEN_SECRET --repo gentrop-cloud/gentrop-terraform-modules --body "$(terraform output -raw cloudbuild_github_token_secret)"
```

A conta de faturamento é confidencial: vai num **secret** do repositório, nunca
numa var, num commit ou num `--body`. O comando abaixo pede o valor no terminal:

```bash
gh secret set CLIENTS_BILLING_ACCOUNT --repo gentrop-cloud/gentrop-terraform-modules
```

## Onboarding de um cliente novo

Nada a fazer aqui: rode o stack `project` pelo portal antes dos outros.

## Migração do projeto de prod para o seed

Até a versão anterior, o WIF, a `tf-provisioner` e o secret
`cloudbuild-github-token` deste root ficavam no `geapp-gentrop-prod-0001`, e a
`tf-provisioner` tinha papéis nos projetos de `client_project_ids`.

- **Antes do apply**, tire a `tf-provisioner` do prod do state, senão o apply a
  apaga. Ela continua existindo como a conta do próprio prod:
  `terraform state rm 'module.wif.google_service_account.this[0]'`
- Confira no `terraform plan` que só saem o WIF antigo, o secret antigo e os
  papéis da `tf-provisioner` nos projetos de `client_project_ids`.
- Regrave o PAT no secret novo:
  `printf '%s' "<token>" | gcloud secrets versions add cloudbuild-github-token --data-file=- --project=geapp-prod-seed-0001`
- Projetos que já existiam (como o prod) não passaram pelo stack `project`: a
  `tf-provisioner` deles precisa dos papéis de `tf_provisioner_roles` no próprio
  projeto, da ligação `workloadIdentityUser` com o WIF novo e de acesso ao
  bucket, concedidos à mão ou importando esses recursos no state
  `clientes/<slug>/project`.
