# gentrop-terraform-modules

Módulos Terraform reutilizáveis pra provisionar projetos GCP (Cloud Run,
Cloud SQL, Artifact Registry, Secret Manager, Workload Identity Federation).

## Módulos

- [`artifact-registry`](modules/artifact-registry) — repositório Docker
- [`secret-manager`](modules/secret-manager) — containers de secret (sem valor)
- [`cloud-run`](modules/cloud-run) — serviço Cloud Run v2, com SA de runtime e
  suporte a env vars/secrets, Cloud SQL e invocação autenticada via OIDC
- [`cloud-sql-postgress`](modules/cloud-sql-postgress) — instância Postgres
- [`workload-identity`](modules/workload-identity) — WIF pra GitHub Actions
- [`cloud-scheduler-http`](modules/cloud-scheduler-http) — job HTTP agendado,
  autenticado via OIDC
- [`cloud-tasks-queue`](modules/cloud-tasks-queue) — fila de distribuição de
  carga, com rate limiting/retry
- [`firestore-database`](modules/firestore-database) — banco Firestore Native
- [`bigquery-dataset`](modules/bigquery-dataset) — dataset + tabelas BigQuery
- [`vertex-ai-agent-engine`](modules/vertex-ai-agent-engine) — SA, bucket de
  staging e registro do Vertex AI Reasoning Engine

## Exemplos

Cada pasta abaixo é standalone: edite o `main.tf` com os dados do seu projeto GCP e
rode `terraform init` + `terraform apply` direto — sem precisar passar por git/CI.

- [`artifact-registry-test`](examples/artifact-registry-test) — só o repositório
- [`secret-manager-test`](examples/secret-manager-test) — só os secrets
- [`cloud-run-test`](examples/cloud-run-test) — só o Cloud Run (imagem placeholder)
- [`cloud-sql-test`](examples/cloud-sql-test) — só o Cloud SQL
- [`github-actions-wif`](examples/github-actions-wif) — WIF pra GitHub Actions
- [`firestore-database-test`](examples/firestore-database-test) — só o Firestore
- [`bigquery-dataset-test`](examples/bigquery-dataset-test) — só o BigQuery
- [`cloud-tasks-queue-test`](examples/cloud-tasks-queue-test) — só a fila de Cloud Tasks
- [`cloud-scheduler-http-test`](examples/cloud-scheduler-http-test) — só o job de Cloud Scheduler
- [`vertex-ai-agent-engine-test`](examples/vertex-ai-agent-engine-test) — só o Vertex AI Agent Engine
- [`artifact-registry-secret-manager-cloud-run`](examples/artifact-registry-secret-manager-cloud-run) —
  stack completa pós-criação do projeto (registry + secrets + Cloud SQL + Cloud Run
  já conectados entre si)
- [`hyper-agent`](examples/hyper-agent) — Cloud Scheduler + Cloud Tasks +
  2 Cloud Run + Firestore + BigQuery + Vertex AI Agent Engine, já conectados
  entre si

Cada exemplo tem seu próprio README com o passo a passo.
