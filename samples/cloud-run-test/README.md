# Exemplo: Cloud Run

Sobe um serviço isolado no Cloud Run usando o módulo [`cloud-run`](../../modules/cloud-run),
com a imagem pública `hello` de placeholder (não depende de Artifact Registry nem de
Secret Manager) — serve só pra validar o módulo sozinho.

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

Depois do apply, `terraform output service_url` mostra a URL — deve carregar a página
de exemplo do Cloud Run.
