# samples

Bancada de teste dos módulos de [`modules/`](../modules). Cada pasta é uma
configuração Terraform pequena e standalone, que chama um ou mais módulos pelo caminho
local (`../../modules/<m>`) para ver o módulo funcionando de verdade num projeto GCP,
antes de ele ir para as stacks do manager ou para uma tag usada em `projects/`.

O que um sample **não** é: infra de produção. Ele não tem state remoto (o
`terraform.tfstate` fica na pasta, ignorado pelo git), não roda no CI e pode ser
destruído a qualquer momento. Infra que precisa ficar de pé vai para
[`projects/`](../projects), incluindo as [stacks do manager](../projects/geapp-manager/prod/stacks).

## Para que serve

- Testar uma mudança num módulo antes do PR (o sample usa o código local, não a tag).
- Ver um exemplo de uso de cada módulo, com as variáveis mínimas preenchidas.
- Ponto de partida para montar uma stack nova em `projects/`: copie o sample e troque
  o `source` para a tag.

## Como usar

1. Abra o `main.tf` do sample e troque o `project_id` pelo projeto de teste (os
   samples vêm com `estudos-jean-pereira`).
2. `gcloud auth application-default login`
3. `terraform init` e `terraform apply` na pasta do sample.
4. Terminou o teste: `terraform destroy`.

Cada sample tem um README com o passo a passo e o que conferir depois do apply.

## Samples

Um por módulo, com o mesmo nome da pasta em `modules/`:

- [`artifact-registry`](artifact-registry) — só o repositório
- [`secret-manager`](secret-manager) — só os secrets
- [`cloud-run`](cloud-run) — só o Cloud Run (imagem placeholder)
- [`cloud-sql`](cloud-sql) — só o Cloud SQL (módulo `cloud-sql-postgress`)
- [`firestore-database`](firestore-database) — só o Firestore
- [`bigquery-dataset`](bigquery-dataset) — só o BigQuery
- [`cloud-tasks-queue`](cloud-tasks-queue) — só a fila de Cloud Tasks
- [`cloud-scheduler-http`](cloud-scheduler-http) — só o job de Cloud Scheduler
- [`vertex-ai-agent-engine`](vertex-ai-agent-engine) — só o Vertex AI Agent Engine
- [`github-actions-wif`](github-actions-wif) — WIF pra GitHub Actions (módulo
  `workload-identity`)

Combinações de módulos já conectados entre si:

- [`artifact-registry-secret-manager-cloud-run`](artifact-registry-secret-manager-cloud-run) —
  registry + secrets + Cloud SQL + Cloud Run. **Atenção:** aponta para
  `geapp-gentrop-prod-0001`, cuja infra hoje é gerida por
  [`projects/geapp/prod/app`](../projects/geapp/prod/app). Não rode `apply` nele com
  esse `project_id`.
- [`hyper-agent`](hyper-agent) — Cloud Scheduler + Cloud Tasks + 2 Cloud Run +
  Firestore + BigQuery + Vertex AI Agent Engine
