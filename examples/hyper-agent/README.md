# Exemplo: hyper-agent

Stack completa do [gentrop-cloud/hyper-agent](https://github.com/gentrop-cloud/hyper-agent):
Cloud Scheduler (10h/14h) → Cloud Run #1 (`hyper-agent-gatilho-scheduler`) →
Cloud Tasks (`fila-disparos-hyperproject`) → Cloud Run #2
(`hyper-agent-mensagens-chat`) → Vertex AI Agent Engine, com Firestore e
BigQuery de apoio, mais a infra de CI/CD (Artifact Registry, Secret Manager
pro SMTP, Workload Identity Federation pro GitHub Actions do repo da
aplicação).

## Como usar

1. Abra o `main.tf` e troque `local.project_id` pelo projeto GCP de destino.
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
   O `module.agent_engine` já vem com `count = 0` — cria a service account, o
   bucket de staging e habilita as APIs, mas ainda **não** registra o
   Reasoning Engine (isso exige um objeto real no bucket, ver passo 6).
5. Copie os outputs `workload_identity_provider`, `deployer_service_account_email`,
   `artifact_registry_url` e `agent_engine_staging_bucket` pros Secrets/Variables
   do GitHub Actions do repo `hyper-agent` — o passo a passo completo (o que é
   Secret vs. Variable, e a ordem de bootstrap do Agent Engine) está no
   `DEPLOY.md` desse outro repositório.
6. No repo `hyper-agent`, rode
   `STAGING_BUCKET=gs://<bucket> python -m scripts.bootstrap_agent_engine_placeholder`
   (uma vez só) pra subir um pickle placeholder pro bucket.
7. Volte aqui, troque `count = 0` para `count = 1` em `module.agent_engine`
   ([main.tf](main.tf)), rode `terraform apply` de novo, e copie o output
   `reasoning_engine_name` pro secret `REASONING_ENGINE_NAME` do GitHub.
8. Dali em diante, o pipeline `deploy.yml` do repo `hyper-agent` cuida do
   resto — build+push+deploy dos 2 Cloud Run e `agent_engines.update` no
   Agent Engine, a cada push relevante em `main`.

## O que este exemplo NÃO faz

- **Não builda nem faz deploy do código** dos dois Cloud Run (usa a imagem
  placeholder default do módulo `cloud-run`) — isso é o workflow `deploy.yml`
  do repo `hyper-agent`.
- **Não builda nem envia o bundle real do agente** pro Vertex AI Agent Engine
  — só o placeholder de bootstrap (passo 6 acima); quem publica o agente de
  verdade é `scripts/deploy_agent_engine.py` (CI) via `agent_engines.update`.
- **Não cria o app do Google Chat** nem o espaço/`space_id` — isso é
  configurado no Google Chat API / Admin Console, fora do Terraform.
- Não popula a coleção `mapeamento_spaces` no Firestore nem cria tabelas no
  dataset de auditoria além do dataset em si — schemas de tabela específicos
  entram via `tables` no módulo `bigquery-dataset` quando definidos.
- `PILOT_WHITELIST` (lista de e-mails do piloto que o `gatilho_scheduler` usa)
  fica sem valor por padrão — defina como env var separada se quiser habilitar
  a whitelist via Terraform; sem ela, `ENABLE_WHITELIST=true` (default do
  código) bloqueia todo mundo, que é o lado seguro.

Depois do apply, use os outputs `gatilho_scheduler_url` e `mensagens_chat_url`
pra configurar o CD, e os de WIF/Artifact Registry/bucket (passo 5) pros
Secrets/Variables do GitHub.
