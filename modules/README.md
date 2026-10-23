# modules

Biblioteca de módulos Terraform reutilizáveis da Gentrop para o Google Cloud Platform
(GCP). Cada módulo encapsula a forma padronizada de criar um serviço do GCP, de modo
que os projetos e os samples deste repositório informem apenas os dados específicos
do seu contexto.

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Princípios de design](#2-princípios-de-design)
3. [Catálogo](#3-catálogo)
4. [Referência dos módulos](#4-referência-dos-módulos)
5. [Layout de um módulo](#5-layout-de-um-módulo)
6. [Requisitos](#6-requisitos)
7. [Formas de consumo](#7-formas-de-consumo)
8. [Casos de uso](#8-casos-de-uso)
9. [Alteração de um módulo](#9-alteração-de-um-módulo)
10. [Criação de um novo módulo](#10-criação-de-um-novo-módulo)
11. [Pontos de atenção](#11-pontos-de-atenção)

## 1. Visão geral

Um módulo é um conjunto coeso de recursos Terraform que representa um serviço do GCP
configurado segundo o padrão da Gentrop: ativação das APIs necessárias, conta de
serviço dedicada quando aplicável, permissões de IAM e parâmetros padrão seguros.

Os módulos são consumidos por três tipos de configuração:

| Consumidor | Pasta | Referência ao módulo |
| --- | --- | --- |
| Projetos aplicados manualmente | `projects/<projeto>/<ambiente>/<stack>/` | Tag Git (`?ref=vX.Y.Z`) |
| Projetos aplicados por pipeline | Definida pelo projeto | Caminho local, a partir da branch `main` |
| Samples | `samples/<módulo>/` | Caminho local |

## 2. Princípios de design

| Princípio | Aplicação |
| --- | --- |
| **Sem backend** | Nenhum módulo declara backend. O consumidor decide em qual state os recursos são registrados. |
| **Sem provider do Google** | Nenhum módulo configura o provider `google`. O consumidor define projeto e credenciais. A única exceção de provider é o `postgresql`, configurado pelo `cloud-sql-postgress` para executar os GRANTs na própria instância. |
| **APIs sob demanda** | Os módulos habilitam as APIs de que dependem, controladas pela variável `enable_apis` (padrão `true`); o `cloud-sql-postgress` as habilita sempre, sem essa variável. As APIs nunca são desabilitadas em um `destroy`. |
| **Identidade dedicada** | Módulos de serviços que executam código ou chamam outros serviços criam uma conta de serviço própria (`create_service_account`, padrão `true`) ou reutilizam uma existente (`existing_service_account_email`). |
| **Menor privilégio** | Os papéis de IAM são informados explicitamente pelo consumidor (`service_account_roles`, `invoker_members`, `enqueuer_members`), sem papéis amplos por padrão. |
| **Interface documentada** | Toda variável declara `type` e `description`; toda saída declara `description`. |
| **Compatibilidade** | Novos comportamentos entram por variáveis cujo valor padrão preserva o comportamento existente. |

## 3. Catálogo

| Módulo | Serviço | Recursos criados | Sample |
| --- | --- | --- | --- |
| [`artifact-registry`](artifact-registry) | Artifact Registry | Repositório de artefatos (Docker por padrão) | [`artifact-registry`](../samples/artifact-registry) |
| [`bigquery-dataset`](bigquery-dataset) | BigQuery | Dataset e tabelas opcionais | [`bigquery-dataset`](../samples/bigquery-dataset) |
| [`cloud-run`](cloud-run) | Cloud Run (v2) | Serviço, conta de runtime, papéis e invocadores | [`cloud-run`](../samples/cloud-run) |
| [`cloud-scheduler-http`](cloud-scheduler-http) | Cloud Scheduler | Job HTTP autenticado por OIDC e conta de invocação | [`cloud-scheduler-http`](../samples/cloud-scheduler-http) |
| [`cloud-sql-postgress`](cloud-sql-postgress) | Cloud SQL para PostgreSQL | Instância, banco, usuário administrador, usuários IAM e GRANTs | [`cloud-sql`](../samples/cloud-sql) |
| [`cloud-tasks-queue`](cloud-tasks-queue) | Cloud Tasks | Fila com controle de vazão e de novas tentativas | [`cloud-tasks-queue`](../samples/cloud-tasks-queue) |
| [`firestore-database`](firestore-database) | Firestore | Banco em modo nativo | [`firestore-database`](../samples/firestore-database) |
| [`secret-manager`](secret-manager) | Secret Manager | Containers de segredos, sem valores | [`secret-manager`](../samples/secret-manager) |
| [`vertex-ai-agent-engine`](vertex-ai-agent-engine) | Vertex AI Agent Engine | Reasoning Engine, bucket de staging e conta de runtime | [`vertex-ai-agent-engine`](../samples/vertex-ai-agent-engine) |
| [`workload-identity`](workload-identity) | IAM (Workload Identity Federation) | Pool, provedor OIDC do GitHub e conta de serviço | [`github-actions-wif`](../samples/github-actions-wif) |

## 4. Referência dos módulos

Esta seção resume a interface de cada módulo. A lista completa de variáveis, com tipos
e descrições, está no `variables.tf` e no `README.md` de cada módulo.

### 4.1 `artifact-registry`

Cria um repositório no Artifact Registry.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id` |
| Principais opcionais | `location` (`us-central1`), `repository_id` (`cloud-run-source-deploy`), `format` (`DOCKER`), `description` |
| Saídas | `repository_id`, `repository_name`, `repository_url` |
| API | `artifactregistry.googleapis.com` |

### 4.2 `bigquery-dataset`

Cria um dataset do BigQuery e, opcionalmente, tabelas com esquema informado em JSON.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id`, `dataset_id` |
| Principais opcionais | `location` (`US`), `tables` (mapa `table_id` → esquema e proteção contra exclusão), `delete_contents_on_destroy` (`false`) |
| Saídas | `dataset_id`, `table_ids` |
| API | `bigquery.googleapis.com` |

Com `delete_contents_on_destroy = false`, o `destroy` falha se o dataset contiver
tabelas não gerenciadas pelo Terraform (por exemplo, criadas por um sink de logs).

### 4.3 `cloud-run`

Cria um serviço Cloud Run (v2) com conta de serviço própria, variáveis de ambiente
comuns e provenientes do Secret Manager, conexão opcional com o Cloud SQL e controle
de invocação.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id`, `service_name` |
| Contêiner | `image` (imagem pública de exemplo), `cpu` (`1`), `memory` (`512Mi`) |
| Configuração | `env_vars`, `secret_env_vars` (nome da variável → id do segredo, sempre na versão `latest`), `cloudsql_connection_name` |
| Acesso | `allow_unauthenticated` (`true`), `invoker_members` |
| Identidade | `create_service_account` (`true`), `service_account_id` (`cloud-run-runtime`), `existing_service_account_email`, `service_account_roles` |
| Proteção | `deletion_protection` (`false`) |
| Saídas | `service_url`, `service_name`, `service_account_email` |
| API | `run.googleapis.com` |

O módulo ignora alterações de imagem e de variáveis de ambiente após a criação do
serviço (ver [seção 11](#11-pontos-de-atenção)).

### 4.4 `cloud-scheduler-http`

Cria um job do Cloud Scheduler que chama um endpoint HTTP(S), autenticado por token
OIDC de uma conta de serviço.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id`, `name`, `schedule` (cron), `uri` |
| Principais opcionais | `region` (`us-central1`), `time_zone` (`America/Sao_Paulo`), `http_method` (`POST`), `body`, `headers` |
| Identidade | `create_service_account` (`true`), `service_account_id` (`cloud-scheduler-invoker`), `existing_service_account_email` |
| Saídas | `service_account_email`, `job_name` |
| API | `cloudscheduler.googleapis.com` |

A conta do job deve ser incluída nos invocadores do destino (por exemplo,
`invoker_members` do módulo `cloud-run`).

### 4.5 `cloud-sql-postgress`

Cria uma instância do Cloud SQL para PostgreSQL com banco lógico, usuário
administrador, usuários autenticados por IAM e os GRANTs desses usuários.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id`, `instance_name`, `database_name`, `db_admin_password` |
| Instância | `region` (`us-central1`), `db_tier` (`db-f1-micro`), `database_version` (`POSTGRES_15`) |
| Acesso | `iam_database_users`, `authorized_networks`, `use_cloudsql_connector` (`false`) |
| Proteção | `deletion_protection` (`true`) |
| Saídas | `instance_connection_name`, `instance_ip_address`, `database_name`, `instance_name` |
| APIs | `sqladmin.googleapis.com`, `iam.googleapis.com` |

Os GRANTs são executados pelo provider `postgresql`, que se conecta à instância pelo
IP público (exigindo o IP de quem aplica em `authorized_networks`) ou, com
`use_cloudsql_connector = true`, pelo Cloud SQL connector com as credenciais do GCP.

### 4.6 `cloud-tasks-queue`

Cria uma fila do Cloud Tasks com controle de vazão, útil para amortecer chamadas a
serviços com limites de cota.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id`, `name` |
| Vazão e repetição | `max_dispatches_per_second` (`1`), `max_concurrent_dispatches` (`1`), `max_attempts` (`5`) |
| Acesso | `enqueuer_members` (recebem `roles/cloudtasks.enqueuer` na fila) |
| Saídas | `queue_id`, `queue_name` |
| API | `cloudtasks.googleapis.com` |

### 4.7 `firestore-database`

Cria um banco do Firestore em modo nativo.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id` |
| Principais opcionais | `database_id` (`(default)`), `location_id` (`us-central1`) |
| Proteção | `delete_protection_state` (`DELETE_PROTECTION_ENABLED`), `deletion_policy` (`ABANDON`), `point_in_time_recovery_enablement` (desabilitado) |
| Saídas | `name` |
| API | `firestore.googleapis.com` |

Com `deletion_policy = ABANDON`, um `destroy` apenas remove o banco do state, sem
excluí-lo. A exclusão efetiva exige `DELETE` e a proteção desabilitada.

### 4.8 `secret-manager`

Cria containers de segredos no Secret Manager, sem valores.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id`, `secret_ids` |
| Saídas | `secret_ids`, `secret_names` |
| API | `secretmanager.googleapis.com` |

Os valores são gravados posteriormente, por processo próprio, por pipeline ou por
recursos `google_secret_manager_secret_version` no consumidor. O Cloud Run exige ao
menos uma versão para cada segredo referenciado.

### 4.9 `vertex-ai-agent-engine`

Cria o Reasoning Engine do Vertex AI Agent Engine, o bucket de staging do pacote do
agente e a conta de runtime.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id`, `display_name`, `staging_bucket_name` (nome global e único) |
| Principais opcionais | `region` (`us-central1`), `description`, `package_spec` (URIs do pacote no GCS) |
| Controle | `create_reasoning_engine` (`true`): com `false`, cria apenas o bucket, para que o CI da aplicação publique o pacote antes da criação do engine |
| Identidade | `create_service_account` (`true`), `service_account_id` (`vertex-agent-engine-runtime`), `existing_service_account_email`, `service_account_roles` |
| Saídas | `reasoning_engine_name`, `service_account_email`, `staging_bucket_name` |
| APIs | `aiplatform.googleapis.com`, `storage.googleapis.com` |

Com `package_spec = null`, o engine é criado sem código, e o CI da aplicação publica o
agente depois. O módulo ignora alterações na especificação do engine, para não
reverter publicações feitas pelo CI.

### 4.10 `workload-identity`

Cria a federação de identidade para que workflows do GitHub Actions autentiquem no
GCP sem chaves de conta de serviço.

| Aspecto | Detalhe |
| --- | --- |
| Obrigatórias | `project_id` |
| Pool e provedor | `pool_id` (`github-actions-pool`), `provider_id` (`github-oidc-provider`), `attribute_mapping`, `attribute_condition`, `allowed_audiences` |
| Identidade | `create_service_account` (`true`), `service_account_id` (`github-deployer`), `existing_service_account_email`, `service_account_roles` |
| Autorização | `github_repositories` (repositórios `org/repo` autorizados a assumir a conta) |
| Saídas | `workload_identity_provider`, `service_account_email`, `workload_identity_pool_id` |
| APIs | `iam.googleapis.com`, `iamcredentials.googleapis.com`, `sts.googleapis.com` |

Recomenda-se sempre informar `attribute_condition`, restringindo o repositório e,
quando aplicável, a branch (`assertion.ref`) autorizados.

## 5. Layout de um módulo

```
modules/<módulo>/
├── main.tf        # Recursos
├── variables.tf   # Entradas, com type e description
├── outputs.tf     # Saídas, com description
├── versions.tf    # required_version e required_providers
└── README.md      # Finalidade, exemplo de uso, entradas e saídas
```

Arquivos adicionais são aceitos quando separam responsabilidades distintas. O
`cloud-sql-postgress`, por exemplo, mantém as APIs em `services.tf` e os GRANTs em
`permissions.tf`.

## 6. Requisitos

| Módulos | Terraform | Providers |
| --- | --- | --- |
| Todos, exceto `cloud-sql-postgress` | 1.5 ou superior | `hashicorp/google` 5.0 ou superior |
| `cloud-sql-postgress` | 1.3 ou superior | `hashicorp/google` 4.0 ou superior, `cyrilgdn/postgresql` 1.21 ou superior, `hashicorp/time` 0.9 ou superior |

Os consumidores podem exigir versões mais recentes no seu próprio `versions.tf`.

## 7. Formas de consumo

**Caminho local**, usado pelos samples e pelos projetos aplicados por pipeline. O
código do módulo é sempre o da cópia local do repositório:

```hcl
module "app" {
  source     = "../../modules/cloud-run"
  project_id = "<project-id>"
  service_name = "<servico>"
}
```

**Tag Git**, usada pelos projetos aplicados manualmente. O código do módulo é o da tag
informada, independentemente de alterações posteriores na `main`:

```hcl
module "app" {
  source     = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
  project_id = "<project-id>"
  service_name = "<servico>"
}
```

Após alterar a referência `?ref=`, execute `terraform init -upgrade` para baixar o
código da nova tag.

## 8. Casos de uso

Os casos abaixo usam o módulo `cloud-run` como exemplo e dois projetos aplicados
manualmente, `projects/<projeto-a>/<ambiente>/<stack>` e
`projects/<projeto-b>/<ambiente>/<stack>`, ambos na tag `v1.0.0`.

### 8.1 Alterar o Cloud Run de um único projeto

**Situação:** a alteração usa um parâmetro que o módulo já oferece, como memória,
CPU, variáveis de ambiente ou papéis da conta de serviço.

**Procedimento:**

1. Não altere `modules/`. Abra o `main.tf` do projeto a ser alterado, por exemplo
   `projects/<projeto-a>/<ambiente>/<stack>/main.tf`.
2. Altere o argumento no bloco do módulo:
   ```hcl
   module "app" {
     source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
     # ...
     memory = "1Gi"
   }
   ```
3. Execute `terraform plan` na pasta da stack e confirme que apenas o serviço
   pretendido é alterado.
4. Abra um Pull Request com o resultado do `plan` e, após o merge, execute
   `terraform apply`.

**Resultado:** apenas o projeto A é alterado. O projeto B permanece inalterado.

### 8.2 Alterar o Cloud Run de vários projetos

**Situação:** a alteração muda o comportamento do módulo, como um recurso novo, uma
variável nova ou um padrão diferente.

**Procedimento:**

1. Altere [`modules/cloud-run`](cloud-run), preservando o comportamento anterior como
   padrão.
2. Valide a alteração em [`samples/cloud-run`](../samples/cloud-run).
3. Abra um Pull Request e, após o merge, publique a nova versão:
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```
4. Em cada projeto que deve receber a alteração, troque `?ref=v1.0.0` por
   `?ref=v1.1.0` nos blocos que usam `modules/cloud-run`.
5. Em cada uma dessas pastas, execute `terraform init -upgrade`, `terraform plan` e,
   após revisão, `terraform apply`.

**Resultado:** apenas os projetos que adotaram a `v1.1.0` recebem a alteração. Os que
permanecem na `v1.0.0` não mudam. Projetos aplicados por pipeline, que usam o caminho
local, recebem a alteração na próxima execução após o merge, sem tag.

## 9. Alteração de um módulo

### 9.1 Regras de compatibilidade

- Uma alteração que recria ou modifica recursos existentes deve ficar atrás de uma
  variável cujo valor padrão mantém o comportamento atual. Exemplo: a variável
  `database_version` do `cloud-sql-postgress` foi introduzida com o padrão
  `POSTGRES_15`, a versão até então fixa no módulo.
- A remoção ou renomeação de variáveis e saídas é uma alteração incompatível e exige
  nova versão MAJOR.
- A inclusão de variável com padrão compatível exige nova versão MINOR; uma correção
  sem mudança de interface, nova versão PATCH.

### 9.2 Procedimento

1. Altere o módulo e o seu `README.md`.
2. Execute `terraform fmt -recursive` e `terraform validate` no sample correspondente.
3. Aplique o sample em um projeto de teste e confira o comportamento.
4. Execute `terraform plan` nos consumidores afetados para avaliar o impacto,
   especialmente nos projetos aplicados por pipeline.
5. Abra o Pull Request descrevendo a alteração, o impacto e a versão a publicar.
6. Após o merge, publique a tag e atualize os projetos que devem adotá-la.

## 10. Criação de um novo módulo

1. Crie `modules/<módulo>/` com o layout da [seção 5](#5-layout-de-um-módulo).
2. Siga os [princípios de design](#2-princípios-de-design): sem backend, sem provider
   do Google, APIs controladas por `enable_apis` e mantidas no `destroy`
   (`disable_on_destroy = false`), identidade dedicada e papéis explícitos.
3. Documente o módulo no seu `README.md`, com exemplo de uso.
4. Crie o sample correspondente em `samples/<módulo>/`.
5. Inclua o módulo no [catálogo](#3-catálogo) deste documento e o sample em
   [`samples/README.md`](../samples/README.md).
6. Após o merge, publique uma nova versão MINOR.

## 11. Pontos de atenção

- **Cloud Run público por padrão.** O `cloud-run` usa `allow_unauthenticated = true`.
  Serviços que só devem ser chamados por outros serviços precisam informar `false` e
  listar os chamadores em `invoker_members`.
- **Configuração do Cloud Run após a criação.** O `cloud-run` ignora alterações de
  imagem e de variáveis de ambiente depois que o serviço existe, para não disputar a
  configuração com o pipeline de deploy. Uma mudança em `env_vars` ou
  `secret_env_vars` não chega a um serviço já criado: ela deve ser feita pelo deploy da
  aplicação ou manualmente.
- **Proteção contra exclusão heterogênea.** Os padrões variam por módulo: habilitada
  no `cloud-sql-postgress` e no `firestore-database`; desabilitada no `cloud-run`; o
  `bigquery-dataset` impede a exclusão de datasets com tabelas não gerenciadas.
- **Nomes reservados.** Contas de serviço, data stores e outros recursos excluídos
  podem ter o nome reservado pelo GCP por um período. Ao recriar, pode ser necessário
  usar outro identificador.
- **Upgrade de versão do PostgreSQL.** Alterar `database_version` em uma instância
  existente provoca atualização de versão principal do banco.
