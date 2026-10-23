# Exemplo: Cloud Scheduler

Sobe um job de Cloud Scheduler isolado usando o módulo
[`cloud-scheduler-http`](../../modules/cloud-scheduler-http) — serve só pra
validar o módulo sozinho. `uri` está com um placeholder (`example.com`); a
criação do job funciona normalmente, mas cada disparo vai falhar até você
trocar por uma URL real (ex: um Cloud Run) e conceder `roles/run.invoker`
pra `service_account_email` nesse alvo.

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
