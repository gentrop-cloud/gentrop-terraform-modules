# Exemplo: Artifact Registry + Secret Manager + Cloud Run

Provisiona a stack completa pós-criação do projeto GCP: repositório no Artifact
Registry, banco no Cloud SQL, os 4 secrets já com valor real e o serviço no Cloud Run
ligado em tudo isso. Usa os módulos
[`artifact-registry`](../../modules/artifact-registry),
[`secret-manager`](../../modules/secret-manager),
[`cloud-sql-postgress`](../../modules/cloud-sql-postgress) e
[`cloud-run`](../../modules/cloud-run).

## Como usar

1. Abra o `main.tf` e troque `local.project_id` pelo projeto GCP de destino. Se o IP
   de quem vai rodar o `apply` for fixo, troque também `local.authorized_networks`
   (deixei `0.0.0.0/0` liberado geral só pra teste).
2. Conecte com esse projeto via `gcloud`:
   ```bash
   gcloud auth application-default login
   gcloud config set project SEU_PROJETO_ID
   ```
3. ```bash
   terraform init
   ```
4. ```bash
   terraform apply
   ```
5. Se aplicou no projeto errado:
   ```bash
   terraform destroy
   ```

## Depois do primeiro apply: login com Google

`NEXTAUTH_SECRET`, `DATABASE_URL` e `DIRECT_URL` já saem populados automaticamente
(gerados/computados pelo próprio Terraform). Só o `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`
ficam com valor fictício, porque criar credencial OAuth 2.0 não tem como automatizar
(não existe recurso Terraform pra isso — é Console mesmo):

1. Pegue o output `oauth_redirect_uri` (já calculado antes mesmo do Cloud Run existir,
   pela URL determinística `SERVICE-PROJECT_NUMBER.REGION.run.app`).
2. No Console: **APIs & Services > Credentials > Create OAuth client ID**, colando esse
   valor como "Authorized redirect URI".
3. Crie um `terraform.tfvars` (já ignorado pelo `.gitignore`) com:
   ```hcl
   google_client_id     = "xxxx.apps.googleusercontent.com"
   google_client_secret = "xxxx"
   ```
4. `terraform apply` de novo — atualiza só o secret e sobe uma nova revision do
   Cloud Run com o login funcionando.

## Depois de mudar o módulo `cloud-run` (ou qualquer módulo local)

O Terraform copia o módulo local pra `.terraform/modules/` no `init` e não atualiza
sozinho. Se editar algo em `modules/*`, rode `terraform init -upgrade` antes do
próximo `apply`/`plan`.
