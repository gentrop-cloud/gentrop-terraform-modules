# Exemplo: Artifact Registry

Cria um repositório Docker no Artifact Registry usando o módulo
[`artifact-registry`](../../modules/artifact-registry).

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
