# geapp / prod / agent

Stack Terraform do **hyper-agent** no ambiente de produção da Gentrop, projeto GCP
`geapp-gentrop-prod-0001`, região `us-central1`.

## Sumário

1. [Finalidade](#1-finalidade)
2. [Arquitetura](#2-arquitetura)
3. [Recursos provisionados](#3-recursos-provisionados)
4. [Contas de serviço e permissões](#4-contas-de-serviço-e-permissões)
5. [Configuração dos serviços](#5-configuração-dos-serviços)
6. [Arquivos e state](#6-arquivos-e-state)
7. [Pré-requisitos](#7-pré-requisitos)
8. [Primeira aplicação](#8-primeira-aplicação)
9. [Integração com o CI/CD do hyper-agent](#9-integração-com-o-cicd-do-hyper-agent)
10. [Operação](#10-operação)
11. [Outputs](#11-outputs)
12. [Pontos de atenção](#12-pontos-de-atenção)

## 1. Finalidade

O hyper-agent é o sistema multiagente que promove a adoção do Gemini Enterprise
entre os colaboradores. Ele envia dicas personalizadas por área e nível de
conhecimento, acompanha o uso real da ferramenta, responde dúvidas pelo Google Chat e
coleta casos de sucesso. Esta stack cria toda a infraestrutura de que o hyper-agent
necessita; o código das aplicações e dos agentes reside no repositório
[gentrop-cloud/hyper-agent](https://github.com/gentrop-cloud/hyper-agent).

A visão geral do projeto está em [`projects/geapp/README.md`](../../README.md). A
mesma arquitetura existe em [`samples/hyper-agent`](../../../../samples/hyper-agent),
para testes, e na stack `gemini-enterprise` do GeApp Manager, para clientes.

## 2. Arquitetura

O hyper-agent opera em três fluxos principais:

| Fluxo | Gatilho | Caminho |
| --- | --- | --- |
| Dicas diárias | Cloud Scheduler, às 10h | Scheduler → Cloud Run de gatilho → Cloud Tasks → Cloud Run de mensagens → Agent Engine → Google Chat ou e-mail |
| Verificação e engajamento | Cloud Scheduler, às 14h | Mesmo caminho, com mensagens diferenciadas para quem já usou e quem ainda não usou a ferramenta no dia |
| Atendimento reativo | Mensagem do usuário no Google Chat | Google Chat → Cloud Run de mensagens → Agent Engine → Google Chat |

O Cloud Run de gatilho consulta a telemetria de licenças pela Discovery Engine API,
cruza com os perfis armazenados no Firestore e enfileira uma tarefa por colaborador.
O Cloud Tasks entrega essas tarefas uma a uma ao Cloud Run de mensagens, que invoca o
agente orquestrador no Vertex AI Agent Engine e entrega a resposta pelo Google Chat,
ou por e-mail quando o colaborador ainda não possui espaço no Chat.

## 3. Recursos provisionados

| Recurso | Módulo ou tipo | Configuração |
| --- | --- | --- |
| APIs adicionais | `google_project_service` | Discovery Engine (telemetria), Cloud Build (build das imagens) e App Hub (exibição do agente no console) |
| Repositório de imagens | `artifact-registry` | Repositório Docker `hyper-agent` |
| Segredo SMTP | `secret-manager` | Segredo `SMTP_PASSWORD`, com valor informado por variável |
| Workload Identity Federation | `workload-identity` | Pool `hyper-agent-gh-pool`, provedor `hyper-agent-gh-provider` e conta `hyper-agent-gh-deployer` para o CI/CD |
| Banco de estado | `firestore-database` | Banco `hyper-project-db-native`, modo nativo |
| Auditoria | `bigquery-dataset` | Dataset `hyper_agent_auditoria` |
| Agentes | `vertex-ai-agent-engine` | Reasoning Engine `hyper-agent-root`, bucket de staging e conta de runtime |
| Serviço de mensagens | `cloud-run` | `hyper-agent-mensagens-chat`, acesso público |
| Fila de disparos | `cloud-tasks-queue` | `fila-disparos-hyperproject`, uma tarefa por segundo e uma por vez |
| Serviço de gatilho | `cloud-run` | `hyper-agent-gatilho-scheduler`, acesso restrito |
| Agendamentos | `cloud-scheduler-http` | `hyper-agent-disparo-10h` e `hyper-agent-disparo-14h`, fuso `America/Sao_Paulo` |

Os módulos são referenciados pela tag `v1.0.0` deste repositório.

## 4. Contas de serviço e permissões

| Conta | Papéis | Uso |
| --- | --- | --- |
| `hyper-agent-mensagens-chat` | `datastore.user`, `bigquery.dataEditor`, `aiplatform.user`, `secretmanager.secretAccessor` | Runtime do Cloud Run de mensagens |
| `hyper-agent-gatilho-scheduler` | `datastore.user`, `discoveryengine.viewer`; enfileirador da fila de disparos | Runtime do Cloud Run de gatilho |
| `vertex-agent-engine-run2` | `aiplatform.user` | Runtime do Reasoning Engine |
| `hyper-agent-disparo-10h` e `hyper-agent-disparo-14h` | Invocadores do Cloud Run de gatilho | Identidade dos agendamentos |
| `hyper-agent-gh-deployer` | `run.admin`, `artifactregistry.writer`, `iam.serviceAccountUser`, `aiplatform.user`, `storage.admin`, `cloudbuild.builds.editor`, `serviceusage.serviceUsageConsumer` | Deploy pelo GitHub Actions do repositório `hyper-agent` |

O Cloud Run de mensagens precisa ser público porque os webhooks do Google Chat não são
assinados como tokens OIDC do Cloud Run; a aplicação valida o token do Google Chat no
próprio código. O Cloud Run de gatilho aceita apenas as contas dos agendamentos. O
Cloud Tasks autentica cada entrega com a conta do Cloud Run de gatilho.

## 5. Configuração dos serviços

Os nomes das variáveis correspondem às leituras de ambiente do código no repositório
`hyper-agent`.

**`hyper-agent-mensagens-chat`**

| Variável | Valor |
| --- | --- |
| `GOOGLE_CLOUD_PROJECT` | Projeto da stack |
| `GOOGLE_CLOUD_LOCATION` | `us-central1` |
| `SMTP_EMAIL` | Remetente do e-mail de contingência |
| `REASONING_ENGINE_ID` | Nome completo do Reasoning Engine, definido na criação do serviço |
| `SMTP_PASSWORD` | Lido do Secret Manager |

**`hyper-agent-gatilho-scheduler`**

| Variável | Valor |
| --- | --- |
| `PROJECT_ID` | Projeto da stack |
| `LOCATION` | `global` (Discovery Engine) |
| `REGION_TASKS` | `us-central1` |
| `QUEUE_NAME` | Nome da fila de disparos |
| `AGENT_ENDPOINT` | URL do Cloud Run de mensagens |
| `SA_EMAIL_INVOKER` | Conta do próprio Cloud Run de gatilho, usada no OIDC das tarefas |

A variável `PILOT_WHITELIST` não é definida pela stack. Sem ela, a lista de permissão
do piloto, habilitada por padrão no código, bloqueia todos os envios, que é o
comportamento seguro.

## 6. Arquivos e state

| Item | Valor |
| --- | --- |
| `main.tf` | Variável `smtp_password`, recursos, chamadas de módulos e outputs |
| `versions.tf` | Terraform 1.5 ou superior, provider `google` 5.0 ou superior e backend |
| `.terraform.lock.hcl` | Versões fixadas dos providers |
| Backend | `gcs`, bucket `gentrop-tfstate` |
| `prefix` | `clientes/geapp-prod-hyper-agent` |

O `prefix` mantém o nome anterior à reorganização das pastas e é distinto do da
stack `app`. Ele não deve ser alterado nem reutilizado.

## 7. Pré-requisitos

1. **Bucket de state** `gentrop-tfstate` existente (ver
   [`../app/README.md`](../app/README.md)).
2. **Senha SMTP.** A senha de aplicativo da conta de e-mail de contingência não pode
   ser automatizada. Informe-a em um `terraform.tfvars` nesta pasta (ignorado pelo
   Git):
   ```hcl
   smtp_password = "<senha de aplicativo>"
   ```
   O valor padrão declarado em `main.tf` é fictício.
3. **Pacote do agente.** Não é necessário antes do `apply`: o Reasoning Engine é
   criado vazio e o CI do repositório `hyper-agent` publica o agente depois (ver
   [seção 8](#8-primeira-aplicação)).
4. **Permissões** no projeto e acesso ao bucket de state.

## 8. Primeira aplicação

O módulo `agent_engine` é chamado sem `package_spec`. Nessa configuração, o Reasoning
Engine é criado vazio no mesmo `apply` que cria o bucket de staging, sem depender de um
pacote do agente no GCS. Como o Cloud Run de mensagens referencia o engine, o Terraform
cria o engine primeiro, e o serviço já nasce com `REASONING_ENGINE_ID`. Isso é
necessário porque o módulo `cloud-run` ignora alterações de variáveis de ambiente em
serviços existentes.

Em um projeto em que o hyper-agent ainda não existe:

1. **Infraestrutura.** Execute:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
   Revise o `plan`: devem existir apenas operações de criação. Não copie o state de
   `samples/hyper-agent`, que pertence a outro projeto.
2. **Credenciais do CI/CD.** Cadastre os outputs no repositório `hyper-agent` (ver
   [seção 9](#9-integração-com-o-cicd-do-hyper-agent)).
3. **Código do agente.** Cada push na `main` do `hyper-agent` que altere os agentes
   publica o código no engine por `agent_engines.update`. O módulo ignora alterações
   na especificação do Reasoning Engine, de modo que o `apply` não reverte a
   publicação. O script `bootstrap_agent_engine_placeholder.py` do `hyper-agent` não é
   necessário neste fluxo.

Em um projeto em que o Reasoning Engine já existe, como o de produção, execute
`terraform init` e `terraform plan`. O `main.tf` contém um bloco `moved` que renomeia o
endereço `module.agent_engine[0]` para `module.agent_engine`, decorrente da remoção do
`count`. O `plan` deve indicar apenas essa movimentação, sem criação, alteração ou
exclusão de recursos. A remoção do `package_spec` não gera diferença, pois a
especificação do engine é ignorada pelo módulo.

Para confirmar que o Cloud Run de mensagens possui a variável:

```bash
gcloud run services describe hyper-agent-mensagens-chat --project=geapp-gentrop-prod-0001 --region=us-central1 --format="value(spec.template.spec.containers[0].env)"
```

Se `REASONING_ENGINE_ID` estiver ausente, defina-a manualmente:

```bash
gcloud run services update hyper-agent-mensagens-chat --project=geapp-gentrop-prod-0001 --region=us-central1 \
  --update-env-vars="REASONING_ENGINE_ID=$(terraform output -raw reasoning_engine_name)"
```

## 9. Integração com o CI/CD do hyper-agent

O repositório `hyper-agent` publica as imagens dos serviços e o pacote do agente por
GitHub Actions, autenticado por Workload Identity Federation. Após o `apply`,
cadastre os valores abaixo em *Settings > Secrets and variables > Actions* daquele
repositório:

| Tipo | Nome no GitHub | Origem nesta stack |
| --- | --- | --- |
| Secret | `WORKLOAD_IDENTITY_PROVIDER` | Output `workload_identity_provider` |
| Secret | `DEPLOYER_SA_EMAIL` | Output `deployer_service_account_email` |
| Secret | `REASONING_ENGINE_NAME` | Output `reasoning_engine_name` |
| Variable | `GCP_PROJECT_ID` | `geapp-gentrop-prod-0001` |
| Variable | `GCP_REGION` | `us-central1` |
| Variable | `ARTIFACT_REGISTRY_REPO` | `hyper-agent` |
| Variable | `AGENT_ENGINE_STAGING_BUCKET` | Output `agent_engine_staging_bucket` |
| Variable | `FIRESTORE_COLLECTION` | `mapeamento_spaces` |

As variáveis `GEMINI_MODEL` (modelo utilizado pelos agentes) e `VERTEX_DATASTORE_ID`
(data store do Vertex AI Search do agente de engajamento) são definidas no próprio
repositório `hyper-agent` e não são criadas por esta stack.

## 10. Operação

- **Alteração de configuração.** Edite `main.tf`, execute `terraform plan`, abra um
  Pull Request com o resultado e aplique após o merge.
- **Nova versão de módulo.** Atualize `?ref=` nas chamadas de módulo, execute
  `terraform init -upgrade` e revise o `plan` antes do `apply`.
- **Horários dos disparos.** Altere `schedule` nos módulos `disparo_10h` e
  `disparo_14h`, em sintaxe cron, no fuso `America/Sao_Paulo`.
- **Vazão da fila.** Ajuste `max_dispatches_per_second` e
  `max_concurrent_dispatches` no módulo `fila_disparos`, observando os limites de cota
  do modelo.

## 11. Outputs

| Output | Conteúdo |
| --- | --- |
| `mensagens_chat_url` | URL do Cloud Run de mensagens, a configurar como endpoint do bot no Google Chat |
| `gatilho_scheduler_url` | URL do Cloud Run de gatilho |
| `firestore_database` | Banco Firestore |
| `bigquery_dataset` | Dataset de auditoria |
| `reasoning_engine_name` | Reasoning Engine, quando habilitado |
| `agent_engine_staging_bucket` | Bucket de staging do pacote do agente |
| `artifact_registry_url` | Repositório de imagens |
| `workload_identity_provider` | Provedor do Workload Identity |
| `deployer_service_account_email` | Conta de deploy do CI/CD |

## 12. Pontos de atenção

- **Conta do Agent Engine.** A conta de runtime usa o identificador
  `vertex-agent-engine-run2`, pois o identificador padrão do módulo foi excluído em
  uma tentativa anterior e permanece reservado pelo GCP por um período.
- **Escopo do Workload Identity.** A condição do provedor restringe o acesso ao
  repositório `gentrop-cloud/hyper-agent`, sem restrição de branch.
- **Variáveis no Cloud Run.** O módulo `cloud-run` ignora alterações de imagem e de
  variáveis de ambiente após a criação do serviço, e o deploy do `hyper-agent`
  substitui apenas a imagem. Assim, uma mudança em `env_vars` nesta stack não chega a
  um serviço existente por nenhum dos dois caminhos: ela deve ser aplicada
  manualmente (`gcloud run services update --update-env-vars`) e registrada no
  `main.tf`, para que um serviço recriado nasça com o mesmo valor.
- **Lista de permissão do piloto.** Enquanto `PILOT_WHITELIST` não for configurada,
  nenhum colaborador recebe mensagens proativas.
