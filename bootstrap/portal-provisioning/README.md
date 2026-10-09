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

## 2. Estado atual: WIF no prod, `geapp-seed-sa` configurada à mão

**Esta versão do root ainda não foi aplicada.** O WIF do GitHub continua no pool
`github-terraform` do `geapp-gentrop-prod-0001`, criado pela versão anterior, e
`WIF_PROVIDER` aponta para ele. A `geapp-seed-sa` foi ligada a esse pool à mão:

```bash
SA=geapp-seed-sa@geapp-prod-seed-0001.iam.gserviceaccount.com

# GitHub (este repo, branch main) assume a geapp-seed-sa pelo pool do prod
gcloud iam service-accounts add-iam-policy-binding $SA --project=geapp-prod-seed-0001   --role=roles/iam.workloadIdentityUser   --member="principalSet://iam.googleapis.com/projects/869019177357/locations/global/workloadIdentityPools/github-terraform/attribute.repository/gentrop-cloud/gentrop-terraform-modules"

# APIs que a geapp-seed-sa usa, com o seed como projeto de cota
gcloud services enable cloudresourcemanager.googleapis.com cloudbilling.googleapis.com iam.googleapis.com --project=geapp-prod-seed-0001

# State do stack project e acesso das tf-provisioner novas ao bucket
gcloud storage buckets add-iam-policy-binding gs://gentrop-tfstate --member="serviceAccount:$SA" --role=roles/storage.admin

# Repassar o PAT do Cloud Build a tf-provisioner de cada projeto novo
gcloud secrets add-iam-policy-binding cloudbuild-github-token --project=geapp-gentrop-prod-0001   --member="serviceAccount:$SA" --role=roles/secretmanager.admin
```

Vars e secret do repositório:

| Nome | Tipo | Valor |
| --- | --- | --- |
| `WIF_PROVIDER` | var | pool `github-terraform` do prod (sem mudança) |
| `SEED_SA_EMAIL` | var | `geapp-seed-sa@geapp-prod-seed-0001.iam.gserviceaccount.com` |
| `CLIENTS_FOLDER_ID` | var | id da pasta de clientes |
| `CLOUDBUILD_GITHUB_TOKEN_SECRET` | var | secret do prod (sem mudança) |
| `TF_STATE_BUCKET`, `PORTAL_URL` | var | sem mudança |
| `PORTAL_SA_EMAIL` | var | ainda não definida: o stack project não concede o Secret Manager ao portal |
| `CLIENTS_BILLING_ACCOUNT` | secret | conta de faturamento dos clientes |

`TF_SA_EMAIL` (a `tf-provisioner` do prod) segue no repositório para os runs da
versão anterior do `provision.yml` e deixa de ser lida depois do merge.

A conta de faturamento é confidencial: vai num **secret** do repositório, nunca
numa var, num commit ou num `--body`. O comando abaixo pede o valor no terminal:

```bash
gh secret set CLIENTS_BILLING_ACCOUNT --repo gentrop-cloud/gentrop-terraform-modules
```

## Onboarding de um cliente novo

Nada a fazer aqui: rode o stack `project` pelo portal antes dos outros.

## 3. Próximo passo: mover o WIF para o seed (não aplicado)

O código deste root já descreve o destino: WIF, APIs e secret do PAT no seed, sem
nada no prod. Aplicar substitui os comandos manuais acima.

### Antes do apply

O state deste root ainda é o da versão anterior: WIF, `tf-provisioner` e secret
`cloudbuild-github-token` no `geapp-gentrop-prod-0001`, e papéis da
`tf-provisioner` nos projetos de `client_project_ids`.

- Tire a `tf-provisioner` do prod do state, senão o apply a
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
- Os projetos criados pelo stack `project` antes da mudança ligam a
  `tf-provisioner` ao pool do prod. Depois de trocar `WIF_PROVIDER`, rode de novo
  o stack `project` de cada um para religar ao pool do seed. Por fim, remova à
  mão a ligação da `geapp-seed-sa` com o pool do prod e o papel dela no secret do
  prod (seção 2).

### Aplicar este root

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
