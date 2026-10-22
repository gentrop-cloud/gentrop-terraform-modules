# Exemplo: Cloud SQL (Postgres)

Cria uma instância Postgres usando o módulo
[`cloud-sql-postgress`](../../modules/cloud-sql-postgress).

## Como usar

1. Abra o `main.tf` e ajuste:
   - `project_id` — projeto GCP de destino
   - `db_admin_password` — senha do usuário master
   - `authorized_networks` — IP público de quem vai rodar o `terraform apply` (o módulo
     conecta direto no IP público do Cloud SQL durante o apply pra rodar os `GRANT`s)
   - `iam_database_users` — emails de service accounts que devem virar usuário do banco
     (formato `nome@projeto.iam`, sem `.gserviceaccount.com`; a SA precisa já existir)
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

Instância nova de Cloud SQL costuma levar de 5 a 15 minutos pra ficar pronta — é normal.
