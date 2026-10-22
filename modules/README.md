# modules

Módulos Terraform reutilizáveis, um por serviço GCP. Cada um cria um recurso já
configurado do jeito que a Gentrop usa (APIs ligadas, service account, IAM), para
que as stacks do manager, os `projects/` e os `samples/` só precisem passar os dados do projeto.

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

- Nas stacks do manager e em `samples/`, pelo caminho local (ex.: `source = "../../modules/cloud-run"` num sample).
- Em `projects/`, pela tag:
  `source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"`.

## Casos de uso

Exemplo com o Cloud Run, que o geapp usa em dois projetos: `module "app"` em
[`projects/geapp/prod/app`](../projects/geapp/prod/app) e `module "mensagens_chat"` /
`module "gatilho_scheduler"` em [`projects/geapp/prod/agent`](../projects/geapp/prod/agent).

### Mudar o Cloud Run de um projeto só

A mudança é um valor que o módulo já aceita (memória, CPU, env vars, papéis da SA...).
Não mexa em `modules/`: altere só a chamada do módulo no `main.tf` do projeto.

1. Abra `projects/<projeto>/<ambiente>/<stack>/main.tf`, por exemplo
   `projects/geapp/prod/app/main.tf`.
2. Mude o argumento no bloco do módulo:
   ```hcl
   module "app" {
     source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
     # ...
     memory = "1Gi"
   }
   ```
3. PR → merge → na pasta do projeto, `terraform plan` (só o serviço `app` deve mudar)
   e `terraform apply`.

O `agent` e qualquer outro projeto continuam como estavam.

### Mudar o Cloud Run de vários projetos

A mudança é no comportamento do módulo (um recurso novo, uma variável nova, um
default diferente). Ela é feita uma vez em `modules/` e cada projeto escolhe quando
recebe.

1. Altere [`modules/cloud-run`](cloud-run) e teste em
   [`samples/cloud-run`](../samples/cloud-run).
2. PR → merge → crie a tag: `git tag v1.1.0 && git push origin v1.1.0`.
3. Nos projetos que devem receber a mudança (ex.: `projects/geapp/prod/app/main.tf` e
   `projects/geapp/prod/agent/main.tf`), troque `?ref=v1.0.0` por `?ref=v1.1.0` nos
   blocos que usam `modules/cloud-run`.
4. Em cada uma dessas pastas: `terraform init -upgrade`, `terraform plan` e
   `terraform apply`.

O projeto que continuar no `?ref=v1.0.0` não muda. As [stacks do manager](../projects/geapp-manager/stacks)
usam o caminho local e recebem a mudança no próximo run, sem tag: por isso a regra
abaixo, de deixar o comportamento antigo como default.

## Como mudar um módulo

1. Edite o módulo e teste no sample correspondente em [`samples/`](../samples).
2. Uma mudança que recria ou altera recurso existente entra atrás de variável com o
   default antigo (ex.: `database_version` no `cloud-sql-postgress`). As stacks do manager usam o
   módulo da `main` direto, então sem isso todo cliente do manager recebe a mudança no
   próximo run.
3. Depois do merge, crie uma tag nova (`git tag v1.1.0 && git push origin v1.1.0`) e
   suba o `ref` só nos `projects/` que devem receber a mudança.
