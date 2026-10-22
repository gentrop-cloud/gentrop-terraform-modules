# samples

Configurações Terraform de teste dos módulos de [`modules/`](../modules). Cada sample
é uma configuração pequena e independente, que chama um ou mais módulos pelo caminho
local para validar o seu funcionamento em um projeto GCP real antes que uma alteração
seja publicada em uma nova versão.

## Sumário

1. [Finalidade](#1-finalidade)
2. [O que um sample não é](#2-o-que-um-sample-não-é)
3. [Características](#3-características)
4. [Catálogo](#4-catálogo)
5. [Pré-requisitos](#5-pré-requisitos)
6. [Ciclo de uso](#6-ciclo-de-uso)
7. [Validação de uma alteração em módulo](#7-validação-de-uma-alteração-em-módulo)
8. [Criação de um novo sample](#8-criação-de-um-novo-sample)
9. [Observações por sample](#9-observações-por-sample)
10. [Pontos de atenção](#10-pontos-de-atenção)

## 1. Finalidade

Os samples atendem a três objetivos:

- **Validação.** Testar uma alteração em um módulo com o código local, antes do Pull
  Request e da publicação da tag.
- **Referência de uso.** Demonstrar cada módulo com as variáveis mínimas preenchidas,
  servindo de exemplo para novos consumidores.
- **Ponto de partida.** Servir de base para uma nova stack em `projects/`: basta
  copiar o sample, ajustar o projeto e trocar a referência dos módulos para a tag
  vigente.

## 2. O que um sample não é

Um sample **não é infraestrutura produtiva**. Ele não possui state remoto, não é
executado por pipeline e pode ser destruído a qualquer momento. Infraestrutura que
precisa permanecer em operação deve ser declarada em [`projects/`](../projects), com
state remoto e revisão por Pull Request.

## 3. Características

| Aspecto | Comportamento |
| --- | --- |
| Referência aos módulos | Caminho local (`../../modules/<módulo>`), sempre com o código da cópia de trabalho |
| State | Local (`terraform.tfstate` na pasta), excluído do Git pelo `.gitignore` |
| Backend | Nenhum |
| Projeto de destino | Definido no `main.tf` de cada sample (projeto de teste `estudos-jean-pereira` por padrão) |
| Execução | Manual, por um desenvolvedor |
| Documentação | `README.md` próprio, com o passo a passo e o que conferir após o `apply` |
| Nome | Igual ao do módulo testado, quando o sample cobre um único módulo |

## 4. Catálogo

### 4.1 Samples de um módulo

| Sample | Módulo testado | Outputs |
| --- | --- | --- |
| [`artifact-registry`](artifact-registry) | `artifact-registry` | `repository_url` |
| [`bigquery-dataset`](bigquery-dataset) | `bigquery-dataset` | `dataset_id`, `table_ids` |
| [`cloud-run`](cloud-run) | `cloud-run` (imagem pública de exemplo) | `service_url` |
| [`cloud-scheduler-http`](cloud-scheduler-http) | `cloud-scheduler-http` | `service_account_email` |
| [`cloud-sql`](cloud-sql) | `cloud-sql-postgress` | — |
| [`cloud-tasks-queue`](cloud-tasks-queue) | `cloud-tasks-queue` | `queue_id` |
| [`firestore-database`](firestore-database) | `firestore-database` | `database_name` |
| [`github-actions-wif`](github-actions-wif) | `workload-identity` | `workload_identity_provider`, `service_account_email` |
| [`secret-manager`](secret-manager) | `secret-manager` | `secret_ids` |
| [`vertex-ai-agent-engine`](vertex-ai-agent-engine) | `vertex-ai-agent-engine` | `reasoning_engine_name`, `staging_bucket_name` |

### 4.2 Samples de composição

Combinam vários módulos já conectados entre si, reproduzindo uma arquitetura completa.

| Sample | Módulos | Arquitetura |
| --- | --- | --- |
| [`artifact-registry-secret-manager-cloud-run`](artifact-registry-secret-manager-cloud-run) | `artifact-registry`, `secret-manager`, `cloud-sql-postgress`, `cloud-run` | Aplicação web com registro de imagens, segredos, banco PostgreSQL e serviço Cloud Run |
| [`hyper-agent`](hyper-agent) | `artifact-registry`, `secret-manager`, `workload-identity`, `firestore-database`, `bigquery-dataset`, `vertex-ai-agent-engine`, `cloud-run` (2), `cloud-tasks-queue`, `cloud-scheduler-http` (2) | Sistema multiagente com agendamentos, fila de disparos, dois serviços Cloud Run, Firestore, BigQuery e Vertex AI Agent Engine |

## 5. Pré-requisitos

| Requisito | Detalhe |
| --- | --- |
| Terraform | 1.5 ou superior (o `cloud-sql-postgress` aceita a partir de 1.3) |
| Google Cloud CLI | Autenticado com credenciais de aplicação (`gcloud auth application-default login`) |
| Projeto de teste | Projeto GCP com faturamento ativo e permissões suficientes para criar os recursos do sample |
| Valores manuais | Alguns samples exigem valores em `terraform.tfvars` (ver [seção 9](#9-observações-por-sample)) |

## 6. Ciclo de uso

1. **Configuração.** Abra o `main.tf` do sample e defina o `project_id` do projeto de
   teste.
2. **Autenticação.**
   ```bash
   gcloud auth application-default login
   gcloud config set project <project-id>
   ```
3. **Inicialização e plano.**
   ```bash
   terraform init
   terraform plan
   ```
4. **Aplicação.**
   ```bash
   terraform apply
   ```
5. **Verificação.** Confira os outputs e o comportamento descrito no README do
   sample.
6. **Remoção.** Ao final do teste, remova os recursos para evitar custos:
   ```bash
   terraform destroy
   ```

## 7. Validação de uma alteração em módulo

1. Altere o módulo em `modules/<módulo>/`.
2. No sample correspondente, execute `terraform fmt -recursive`, `terraform init` e
   `terraform validate`.
3. Execute `terraform plan` e confirme que a diferença corresponde exatamente à
   alteração pretendida.
4. Execute `terraform apply` no projeto de teste e verifique o comportamento.
5. Quando a alteração afetar consumidores existentes, aplique-a antes sobre um state
   criado com o código anterior do módulo, para confirmar que não há recriação de
   recursos.
6. Execute `terraform destroy` e registre o resultado no Pull Request.

## 8. Criação de um novo sample

1. Crie `samples/<módulo>/` com o mesmo nome do módulo testado.
2. Inclua um `main.tf` que chame o módulo por `../../modules/<módulo>`, com as
   variáveis mínimas e os outputs necessários para a verificação.
3. Não declare backend: o state deve permanecer local.
4. Documente no `README.md` do sample o passo a passo e o que conferir após o
   `apply`.
5. Inclua o sample no [catálogo](#4-catálogo) deste documento e na tabela de módulos
   de [`modules/README.md`](../modules/README.md).

## 9. Observações por sample

| Sample | Observação |
| --- | --- |
| `artifact-registry-secret-manager-cloud-run` | **Aponta para `geapp-gentrop-prod-0001`**, cuja infraestrutura é gerida por [`projects/geapp/prod/app`](../projects/geapp/prod/app). Não execute `apply` com esse `project_id`; para testes, troque-o pelo projeto de teste. Exige `google_client_id` e `google_client_secret` em `terraform.tfvars`. |
| `cloud-sql` | A instância nasce com `deletion_protection = true`. Para destruir, defina `deletion_protection = false`, execute `terraform apply` e só então `terraform destroy`. |
| `firestore-database` | Com `deletion_policy = ABANDON`, o `destroy` remove o banco apenas do state, sem excluí-lo do projeto. |
| `github-actions-wif` | O `project_id` é uma variável sem valor padrão; informe-o com `-var project_id=<project-id>` ou em `terraform.tfvars`. |
| `hyper-agent` | Exige `smtp_password` em `terraform.tfvars`. O Reasoning Engine é criado vazio no primeiro `apply`; um state criado antes desta versão exige definir `REASONING_ENGINE_ID` manualmente no Cloud Run de mensagens (ver o [README do sample](hyper-agent/README.md)). |
| `vertex-ai-agent-engine` | O Reasoning Engine é criado vazio, sem `package_spec`, em um único `apply`. Para criar apenas o bucket, use `create_reasoning_engine = false`. |

Nos dois samples, o módulo do Agent Engine é chamado sem `package_spec`: o engine nasce
sem código, junto com o bucket de staging, e a esteira de CI da aplicação publica o
agente depois com `agent_engines.update`. Não é necessário publicar um pacote
provisório antes do `apply`.

## 10. Pontos de atenção

- **Custos.** Os samples criam recursos reais e faturáveis (por exemplo, instâncias do
  Cloud SQL e serviços do Vertex AI). Execute `terraform destroy` ao final de cada
  teste.
- **State local.** O `terraform.tfstate` de um sample existe apenas na máquina de quem
  o aplicou. Não o versione, não o compartilhe e não o reutilize em uma stack de
  `projects/`, exceto em uma migração planejada com `terraform init -migrate-state`.
- **Renomeação de pastas.** Arquivos ignorados pelo Git, como o state local e a pasta
  `.terraform/`, não acompanham uma renomeação de pasta feita pelo Git. Mova-os
  manualmente para o novo caminho antes de executar o Terraform.
- **Projeto de teste.** Nunca aponte um sample para um projeto produtivo. O state local
  não conhece os recursos geridos por outras stacks: um `apply` pode conflitar com
  recursos de mesmo nome ou alterar a configuração deles, e o `destroy` de um vínculo
  de IAM idêntico a outro declarado em uma stack produtiva remove o vínculo para
  ambas.
