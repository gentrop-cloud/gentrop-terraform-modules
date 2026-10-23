# Bootstrap do ambiente dev do manager

O dev replica o prod no projeto `geapp-dev-seed-0001` (ADR 0011 do geapp-manager).
Ele não compartilha nenhuma identidade, state, bucket ou pasta de clientes com o
prod:

| | prod | dev |
| --- | --- | --- |
| Branch que roda o `provision.yml` | `main` | `develop` |
| GitHub Environment | `prod` (herda as vars do repo) | `dev` |
| Seed e `geapp-seed-sa` | `geapp-prod-seed-0001` | `geapp-dev-seed-0001` |
| State dos clientes | `gentrop-tfstate` | `geapp-dev-seed-0001-tfstate` (criado aqui) |
| Releases | bucket e tópicos no seed de prod | bucket e tópicos no seed de dev |
| Pasta de clientes | `540065658735` | pasta de dev |
| Manager | local (ngrok) | Cloud Run `geapp-manager` no dev seed (`../hosting`) |

Este root e o `../hosting` são aplicados à mão por quem tem Owner no dev seed. O
state dos dois fica no `gentrop-tfstate`, sob `bootstrap/geapp-manager-dev*`.

Faça os passos na ordem. Cada um depende do anterior.

## 1. Admin da org

```bash
P=geapp-dev-seed-0001
SA=geapp-seed-sa@$P.iam.gserviceaccount.com

gcloud resource-manager folders create --display-name="clientes-dev" --organization=<org_id>   # anote o id
gcloud iam service-accounts create geapp-seed-sa --project=$P
gcloud resource-manager folders add-iam-policy-binding <dev_folder_id> \
  --member="serviceAccount:$SA" --role=roles/resourcemanager.projectCreator
gcloud billing accounts add-iam-policy-binding <billing_account> \
  --member="serviceAccount:$SA" --role=roles/billing.user
```

## 2. Este root

```bash
gcloud auth application-default login
terraform init
terraform apply -var clients_folder_id=<dev_folder_id>
```

## 3. Hosting do manager (`../hosting`)

```bash
cd ../hosting
terraform init
terraform apply
```

O apply grava sozinho o secret `database-url`. Os outros valores entram à mão. O
comando lê o valor do terminal, para que ele não fique no histórico:

```bash
P=geapp-dev-seed-0001
for s in session-secret google-client-id google-client-secret github-app-id github-app-private-key admin-emails; do
  read -rsp "$s: " v; echo; printf '%s' "$v" | gcloud secrets versions add "$s" --data-file=- --project=$P
done
```

- `session-secret`: `openssl rand -base64 48`.
- `github-app-*`: o mesmo GitHub App do prod, que já está instalado na org.
- `admin-emails`: e-mails separados por vírgula.

No OAuth client do Google, adicione `<service_url>/auth/callback` como redirect
autorizado.

## 4. GitHub

Use os outputs de `bootstrap` (B) e de `hosting` (H):

```bash
TM=gentrop-cloud/gentrop-terraform-modules
GM=gentrop-cloud/gentrop-geapp-manager

# Environments presos às suas branches (crie também prod -> main no $TM)
for r in $TM $GM; do
  gh api -X PUT repos/$r/environments/dev --input - <<<'{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
  gh api -X POST repos/$r/environments/dev/deployment-branch-policies -f name=develop -f type=branch
done
gh api -X PUT repos/$TM/environments/prod --input - <<<'{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
gh api -X POST repos/$TM/environments/prod/deployment-branch-policies -f name=main -f type=branch

# provision.yml (dev)
gh variable set WIF_PROVIDER      --repo $TM --env dev --body "<B workload_identity_provider>"
gh variable set SEED_SA_EMAIL     --repo $TM --env dev --body "<B service_account_email>"
gh variable set TF_STATE_BUCKET   --repo $TM --env dev --body "<B state_bucket>"
gh variable set CLIENTS_FOLDER_ID --repo $TM --env dev --body "<dev_folder_id>"
gh variable set PORTAL_URL        --repo $TM --env dev --body "<H service_url>"
gh variable set PORTAL_SA_EMAIL   --repo $TM --env dev --body "<H runtime_service_account>"
gh variable set PROJECT_OWNERS    --repo $TM --env dev --body "user:..."
gh secret   set CLIENTS_BILLING_ACCOUNT --repo $TM --env dev   # pede o valor no terminal

# deploy.yml do manager
gh variable set GCP_PROJECT          --repo $GM --env dev --body geapp-dev-seed-0001
gh variable set WIF_PROVIDER         --repo $GM --env dev --body "<H deployer_workload_identity_provider>"
gh variable set DEPLOYER_SA          --repo $GM --env dev --body "<H deployer_service_account>"
gh variable set CLOUD_SQL_CONNECTION --repo $GM --env dev --body "<H cloud_sql_connection>"
gh variable set PORTAL_URL           --repo $GM --env dev --body "<H service_url>"
```

O environment `prod` não tem vars próprias: ele herda as do repo, e o prod não muda.

## 5. Ligar

1. Faça o merge da PR que trouxe `dev/` e o `provision.yml` novo na `main`. Depois,
   avance a `develop` deste repo para a `main`.
2. Faça o merge, na `develop` do `gentrop-geapp-manager`, da PR que traz o
   `deploy.yml`. O push dispara o primeiro deploy.
3. No manager de dev, rode um `plan` da stack `project` de um cliente de teste. O run
   tem que aparecer na `develop` deste repo, com o environment `dev`.

## Releases de dev

O release WIF de dev só aceita a `refs/heads/develop` dos apps. Até os apps terem um
`publish-release.yml` na `develop` apontando para os outputs `release_*` deste root,
o bucket de dev fica vazio. Nesse caso, um cliente de dev com "Deploy pelo Cloud
Build" falha no primeiro deploy.
