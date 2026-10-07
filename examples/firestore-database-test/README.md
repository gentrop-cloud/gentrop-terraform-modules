# Exemplo: Firestore

Sobe um banco Firestore isolado usando o módulo
[`firestore-database`](../../modules/firestore-database) — serve só pra validar o
módulo sozinho.

## Como usar

1. Abra o `main.tf` e troque `project_id` pelo projeto GCP de destino.
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

Um projeto GCP só pode ter um número limitado de bancos Firestore (e o
`database_id` precisa ser único no projeto) — se já existir um banco de teste
com esse nome, troque `database_id` antes de aplicar.
