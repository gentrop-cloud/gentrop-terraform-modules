# Exemplo: BigQuery

Sobe um dataset BigQuery com uma tabela de exemplo, usando o módulo
[`bigquery-dataset`](../../modules/bigquery-dataset) — serve só pra validar o
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

Pra testar só o dataset (sem tabelas), remova o bloco `tables` — o default
já é `{}`.
