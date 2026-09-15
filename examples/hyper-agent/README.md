# Exemplo: hyper-agent

Stack completa do [gentrop-cloud/hyper-agent](https://github.com/gentrop-cloud/hyper-agent):
Cloud Scheduler (10h/14h) → Cloud Run #1 (`hyper-agent-gatilho-scheduler`) →
Cloud Tasks (`fila-disparos-hyperproject`) → Cloud Run #2
(`hyper-agent-mensagens-chat`) → Vertex AI Agent Engine, com Firestore e
BigQuery de apoio.

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
4. O `module.agent_engine` só aplica com sucesso depois que o CI da
   aplicação já tiver subido o bundle real (pickle + `requirements.txt`)
   pro bucket de staging — o Vertex AI valida e copia esse objeto do GCS na
   hora de criar o recurso. Na primeira vez, aplique todo o resto primeiro:
   ```bash
   terraform apply -target=module.firestore -target=module.auditoria \
     -target=module.mensagens_chat -target=module.fila_disparos \
     -target=module.gatilho_scheduler -target=module.disparo_10h \
     -target=module.disparo_14h -target=google_project_service.discovery_engine
   ```
5. Depois que o CI fizer o primeiro deploy do agente (que sobe o bundle real
   pro bucket `<project_id>-agent-engine-staging`), rode `terraform apply`
   sem `-target` pra registrar o `google_vertex_ai_reasoning_engine`.

## O que este exemplo NÃO faz

- **Não builda nem faz deploy do código** dos dois Cloud Run (usa a imagem
  placeholder default do módulo `cloud-run`) — isso é o pipeline de CD da
  aplicação, via `gcloud run deploy`.
- **Não builda nem envia o bundle do agente** (pickle + `requirements.txt`)
  pro Vertex AI Agent Engine — os URIs em `package_spec` são placeholders;
  quem sobe o bundle real é o CI da aplicação via Vertex AI SDK.
- **Não cria o app do Google Chat** nem o espaço/`space_id` — isso é
  configurado no Google Chat API / Admin Console, fora do Terraform.
- Não popula a coleção `mapeamento_spaces` no Firestore nem cria tabelas no
  dataset de auditoria além do dataset em si — schemas de tabela específicos
  entram via `tables` no módulo `bigquery-dataset` quando definidos.

Depois do apply, use os outputs `gatilho_scheduler_url` e
`mensagens_chat_url` pra configurar o CD de cada serviço, e
`reasoning_engine_name` pra referenciar o Agent Engine no código da
aplicação.
