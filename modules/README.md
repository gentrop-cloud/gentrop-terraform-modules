# modules

Módulos Terraform reutilizáveis, um por serviço GCP. Cada um cria um recurso já
configurado do jeito que a Gentrop usa (APIs ligadas, service account, IAM), para
que `stacks/`, `projects/` e `samples/` só precisem passar os dados do projeto.

Um módulo não tem backend nem `provider "google"`: quem chama decide o projeto e o
state. A exceção é o `cloud-sql-postgress`, que configura o provider `postgresql` para
rodar os GRANTs na própria instância.

## Módulos

| Módulo | O que cria |
| --- | --- |
| [`artifact-registry`](artifact-registry) | repositório Docker |
| [`secret-manager`](secret-manager) | containers de secret (sem valor) |
| [`cloud-run`](cloud-run) | serviço Cloud Run v2, com SA de runtime, env vars/secrets, Cloud SQL e invocação autenticada via OIDC |
| [`cloud-sql-postgress`](cloud-sql-postgress) | instância Postgres, banco, usuário admin e usuários IAM |
| [`workload-identity`](workload-identity) | Workload Identity Federation para GitHub Actions |
| [`cloud-scheduler-http`](cloud-scheduler-http) | job HTTP agendado, autenticado via OIDC |
| [`cloud-tasks-queue`](cloud-tasks-queue) | fila de Cloud Tasks, com rate limiting/retry |
| [`firestore-database`](firestore-database) | banco Firestore Native |
| [`bigquery-dataset`](bigquery-dataset) | dataset + tabelas BigQuery |
| [`vertex-ai-agent-engine`](vertex-ai-agent-engine) | SA, bucket de staging e Vertex AI Reasoning Engine |

Cada pasta tem um README com exemplo de uso, variáveis e outputs.

## Layout de um módulo

```
main.tf        # recursos
variables.tf   # entradas
outputs.tf     # saídas
versions.tf    # required_providers
README.md      # uso
```

O `cloud-sql-postgress` também tem `services.tf` (APIs) e `permissions.tf` (GRANTs).

## Como usar

- Em `stacks/` e `samples/`, pelo caminho local: `source = "../../modules/cloud-run"`.
- Em `projects/`, pela tag:
  `source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"`.

## Como mudar um módulo

1. Edite o módulo e teste no sample correspondente em [`samples/`](../samples).
2. Uma mudança que recria ou altera recurso existente entra atrás de variável com o
   default antigo (ex.: `database_version` no `cloud-sql-postgress`). `stacks/` usa o
   módulo da `main` direto, então sem isso todo cliente do portal recebe a mudança no
   próximo run.
3. Depois do merge, crie uma tag nova (`git tag v1.1.0 && git push origin v1.1.0`) e
   suba o `ref` só nos `projects/` que devem receber a mudança.
