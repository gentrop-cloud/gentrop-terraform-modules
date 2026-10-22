# Exemplo: Secret Manager

Cria os containers de secret (sem valor/version) usando o módulo
[`secret-manager`](../../modules/secret-manager).

## Como usar

1. Abra o `main.tf` e troque `project_id` pelo projeto GCP de destino. Se quiser,
   ajuste também a lista `secret_ids`.
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

Os secrets ficam vazios de propósito — populam depois via `gcloud secrets versions add`
ou pelo pipeline de CD, nunca direto no `.tf`/state.
