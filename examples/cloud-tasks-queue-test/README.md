# Exemplo: Cloud Tasks

Sobe uma fila de Cloud Tasks isolada usando o módulo
[`cloud-tasks-queue`](../../modules/cloud-tasks-queue) — serve só pra validar
o módulo sozinho (sem `enqueuer_members`, ninguém além do dono do projeto
consegue enfileirar tasks nela).

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
