# gentrop-terraform-modules

Módulos Terraform reutilizáveis pra provisionar projetos GCP (Cloud Run,
Cloud SQL, Artifact Registry, Secret Manager, Workload Identity Federation).

## Estrutura

```
modules/                         # módulos reutilizáveis, versionados por tag vX.Y.Z
examples/                        # bancada de teste dos módulos (source local, sem state remoto, sem CI)
stacks/ + bootstrap/             # stacks genéricas aplicadas pelo geapp-portal (provision.yml)
projetos/<projeto>/<ambiente>/<stack>/   # infra fora do portal, aplicada à mão: 1 pasta = 1 state
  ex.: projetos/geapp/prod/app, projetos/geapp/prod/hyper-agent
```

As stacks de `stacks/` usam `../../modules` (o portal sempre roda a `main`). As de
`projetos/` usam o módulo por tag, não pelo caminho local:

```hcl
source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
```

Assim uma mudança em `modules/` só chega num projeto quando você sobe o `ref` dele.

## Fluxo de manutenção

- **Mudar só um projeto**: edite os `.tf` da pasta da stack → PR →
  merge em `main` → na pasta, `terraform plan` e `terraform apply`.
- **Mudar um módulo**: edite `modules/<m>` → teste em `examples/` → merge. Isso já
  chega em `stacks/` no próximo run do portal, então mudança que recria ou atualiza
  recurso existente entra atrás de variável com o default antigo. Para `projetos/`:
  `git tag v1.1.0 && git push origin v1.1.0` → nas stacks que devem receber a mudança,
  troque `?ref=v1.0.0` por `?ref=v1.1.0` e rode `terraform init -upgrade`. As outras
  continuam na versão antiga.
- **Novo projeto/ambiente em `projetos/`**: copie uma pasta de stack para
  `projetos/<projeto>/<ambiente>/<stack>`, troque `project_id` e o `prefix` do backend
  (nunca reaproveite um prefix).

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
