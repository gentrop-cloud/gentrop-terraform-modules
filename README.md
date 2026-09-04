# gentrop-terraform-modules

Módulos Terraform reutilizáveis pra provisionar projetos GCP (Cloud Run,
Cloud SQL, Artifact Registry, Secret Manager, Workload Identity Federation).

## Módulos

- [`artifact-registry`](modules/artifact-registry) — repositório Docker
- [`secret-manager`](modules/secret-manager) — containers de secret (sem valor)
- [`cloud-run`](modules/cloud-run) — serviço Cloud Run v2, com SA de runtime e
  suporte a env vars/secrets e Cloud SQL
- [`cloud-sql-postgress`](modules/cloud-sql-postgress) — instância Postgres
- [`workload-identity`](modules/workload-identity) — WIF pra GitHub Actions

## Exemplos

Cada pasta abaixo é standalone: edite o `main.tf` com os dados do seu projeto GCP e
rode `terraform init` + `terraform apply` direto — sem precisar passar por git/CI.

- [`artifact-registry-test`](examples/artifact-registry-test) — só o repositório
- [`secret-manager-test`](examples/secret-manager-test) — só os secrets
- [`cloud-run-test`](examples/cloud-run-test) — só o Cloud Run (imagem placeholder)
- [`cloud-sql-test`](examples/cloud-sql-test) — só o Cloud SQL
- [`github-actions-wif`](examples/github-actions-wif) — WIF pra GitHub Actions
- [`artifact-registry-secret-manager-cloud-run`](examples/artifact-registry-secret-manager-cloud-run) —
  stack completa pós-criação do projeto (registry + secrets + Cloud SQL + Cloud Run
  já conectados entre si)

Cada exemplo tem seu próprio README com o passo a passo.
