# gentrop-terraform-modules

Repositório de infraestrutura da Gentrop no Google Cloud, em Terraform. Ele guarda:

- os **módulos** reutilizáveis (Cloud Run, Cloud SQL, Artifact Registry, Secret
  Manager, Workload Identity, Cloud Scheduler, Cloud Tasks, Firestore, BigQuery,
  Vertex AI Agent Engine);
- as **stacks** que o geapp-portal aplica para cada cliente;
- os **projetos** aplicados à mão, fora do portal (ex.: geapp prod);
- os **samples** usados para testar cada módulo isolado.

Tudo é montado a partir de `modules/`: as outras pastas só combinam módulos e dizem
em qual projeto GCP e em qual state eles rodam.

## Estrutura

```
modules/                  # módulos reutilizáveis, versionados por tag vX.Y.Z (ver modules/README.md)
samples/                  # bancada de teste dos módulos: source local, state local, sem CI
stacks/                   # stacks genéricas aplicadas pelo geapp-portal, uma por cliente
  project/                #   cria o projeto GCP do cliente e a SA tf-provisioner
  gemini-enterprise/      #   app + hyper-agent + Cloud Build do cliente
bootstrap/                # setup único do provisionamento via portal (WIF, SAs)
projects/<projeto>/<ambiente>/<stack>/   # infra fora do portal, aplicada à mão
  geapp/prod/app/         #   app geapp (Cloud Run + Cloud SQL + secrets)
  geapp/prod/agent/       #   hyper-agent do geapp (Scheduler, Tasks, Firestore, BigQuery, Agent Engine)
scripts/                  # apoio ao CI (envio de log ao portal)
.github/workflows/        # provision.yml: run disparado pelo portal
```

## Como a infra é aplicada

| Onde | Quem aplica | Módulos | State |
| --- | --- | --- | --- |
| `stacks/` | geapp-portal → `provision.yml` (`workflow_dispatch`) | `../../modules`, sempre da `main` | `clientes/<client_slug>/<stack>` |
| `projects/` | você, com `terraform plan` / `apply` na pasta | tag git (`?ref=vX.Y.Z`) | `prefix` no `versions.tf` da pasta |
| `samples/` | você, para testar um módulo | `../../modules` | local (`terraform.tfstate`, ignorado pelo git) |

Nos `projects/` o módulo vem por tag:

```hcl
source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
```

Assim uma mudança em `modules/` só chega num projeto quando você sobe o `ref` dele.

## Fluxo de manutenção

- **Mudar só um projeto**: edite os `.tf` da pasta em `projects/` → PR → merge em
  `main` → na pasta, `terraform plan` e `terraform apply`.
- **Mudar um módulo**: edite `modules/<m>` → teste em `samples/` → PR → merge. A
  mudança já chega em `stacks/` no próximo run do portal; por isso, o que recria ou
  altera recurso existente entra atrás de variável com o default antigo. Para
  `projects/`, crie a tag (`git tag v1.1.0 && git push origin v1.1.0`) e, só nos
  projetos que devem receber a mudança, troque `?ref=v1.0.0` por `?ref=v1.1.0` e rode
  `terraform init -upgrade`.
- **Novo projeto ou ambiente**: copie uma pasta para
  `projects/<projeto>/<ambiente>/<stack>`, troque `project_id` e o `prefix` do backend
  (nunca reaproveite um prefix, nem troque o `project_id` de uma pasta já aplicada).
- **Novo cliente do portal**: não passa por aqui; o portal roda `stacks/project` e
  depois as outras stacks. Setup inicial em
  [`bootstrap/portal-provisioning`](bootstrap/portal-provisioning).

## Samples

Cada pasta é standalone: edite o `main.tf` com os dados do seu projeto GCP e rode
`terraform init` + `terraform apply` direto, sem git/CI. Cada uma tem seu README.

- [`artifact-registry-test`](samples/artifact-registry-test) — só o repositório
- [`secret-manager-test`](samples/secret-manager-test) — só os secrets
- [`cloud-run-test`](samples/cloud-run-test) — só o Cloud Run (imagem placeholder)
- [`cloud-sql-test`](samples/cloud-sql-test) — só o Cloud SQL
- [`github-actions-wif`](samples/github-actions-wif) — WIF pra GitHub Actions
- [`firestore-database-test`](samples/firestore-database-test) — só o Firestore
- [`bigquery-dataset-test`](samples/bigquery-dataset-test) — só o BigQuery
- [`cloud-tasks-queue-test`](samples/cloud-tasks-queue-test) — só a fila de Cloud Tasks
- [`cloud-scheduler-http-test`](samples/cloud-scheduler-http-test) — só o job de Cloud Scheduler
- [`vertex-ai-agent-engine-test`](samples/vertex-ai-agent-engine-test) — só o Vertex AI Agent Engine
- [`artifact-registry-secret-manager-cloud-run`](samples/artifact-registry-secret-manager-cloud-run) —
  stack completa pós-criação do projeto (registry + secrets + Cloud SQL + Cloud Run
  já conectados entre si)
- [`hyper-agent`](samples/hyper-agent) — Cloud Scheduler + Cloud Tasks +
  2 Cloud Run + Firestore + BigQuery + Vertex AI Agent Engine, já conectados
  entre si
