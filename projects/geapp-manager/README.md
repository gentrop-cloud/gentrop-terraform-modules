# geapp-manager

Infraestrutura como código do **GeApp Manager**, a plataforma interna da Gentrop que
automatiza o provisionamento de clientes do Gemini Enterprise no Google Cloud
Platform (GCP).

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Repositórios relacionados](#2-repositórios-relacionados)
3. [Tecnologias](#3-tecnologias)
4. [Arquitetura do provisionamento](#4-arquitetura-do-provisionamento)
5. [Estrutura da pasta](#5-estrutura-da-pasta)
6. [Stacks](#6-stacks)
7. [Bootstrap](#7-bootstrap)
8. [Pipeline de provisionamento](#8-pipeline-de-provisionamento)
9. [Contas de serviço e permissões](#9-contas-de-serviço-e-permissões)
10. [Configuração no GitHub](#10-configuração-no-github)
11. [Procedimentos operacionais](#11-procedimentos-operacionais)
12. [Segurança](#12-segurança)
13. [Pontos de atenção](#13-pontos-de-atenção)

## 1. Visão geral

O GeApp Manager é o portal interno da Gentrop para a adoção do Gemini Enterprise em
clientes. Por meio dele, um administrador cadastra o cliente, informa os valores de
configuração e dispara o provisionamento. A plataforma executa o Terraform em um
workflow do GitHub Actions, acompanha o log da execução em tempo real e registra o
resultado.

Antes do GeApp Manager, provisionar um cliente exigia editar variáveis manualmente,
executar o Terraform na máquina de um operador com state local e configurar os
segredos de deploy um cliente por vez. O GeApp Manager substitui esse processo por
um fluxo padronizado, auditável e isolado por cliente.

Esta pasta contém a parte de infraestrutura desse fluxo:

- as **stacks** que o GeApp Manager aplica no projeto GCP de cada cliente;
- o **bootstrap**, setup único do projeto de controle que viabiliza o pipeline;
- o **script de envio de log** utilizado durante as execuções.

O código da aplicação GeApp Manager reside em um repositório próprio (ver
[seção 2](#2-repositórios-relacionados)).

## 2. Repositórios relacionados

| Repositório | Papel |
| --- | --- |
| [gentrop-cloud/gentrop-geapp-manager](https://github.com/gentrop-cloud/gentrop-geapp-manager) | Código da aplicação GeApp Manager (API e interface web), documentação de produto, arquitetura e registros de decisão (ADRs) |
| [gentrop-cloud/geapp-portal](https://github.com/gentrop-cloud/geapp-portal) | Repositório designado para o GeApp, a aplicação entregue a cada cliente |
| [gentrop-cloud/gemini-enteprise-adoption-portal](https://github.com/gentrop-cloud/gemini-enteprise-adoption-portal) | Origem atual do pacote de release do GeApp (ver [seção 13](#13-pontos-de-atenção)) |
| [gentrop-cloud/hyper-agent](https://github.com/gentrop-cloud/hyper-agent) | Código do hyper-agent: sistema multiagente de engajamento, serviços Cloud Run e pipeline de deploy |
| [gentrop-cloud/gentrop-terraform-modules](https://github.com/gentrop-cloud/gentrop-terraform-modules) | Este repositório: módulos Terraform, stacks, bootstrap e o workflow `provision.yml` |

## 3. Tecnologias

### 3.1 Aplicação GeApp Manager

| Camada | Tecnologia |
| --- | --- |
| Runtime e linguagem | [Bun](https://bun.sh/) 1.3 e TypeScript |
| API | [Elysia](https://elysiajs.com/), com cliente tipado via Eden |
| Interface web | React 19, empacotado com Vite e servido pela própria API (SPA) |
| Estado de dados no cliente | TanStack Query |
| Persistência | PostgreSQL, acessado com Drizzle ORM e migrações via `drizzle-kit` |
| Integração com o GitHub | GitHub App (Octokit), com token de instalação |
| Autenticação de callbacks | Validação de tokens OIDC do GitHub Actions (`jose`) |
| Cifragem de segredos do GitHub | `libsodium` |
| Gestão de segredos no GCP | Cliente oficial do Secret Manager |
| Empacotamento | Imagem Docker única (`oven/bun`) para API e SPA |
| Qualidade | GitHub Actions com lint (ESLint), typecheck, testes (`bun test`) e verificação do índice de ADRs |

### 3.2 Infraestrutura provisionada

| Domínio | Serviços do GCP e ferramentas |
| --- | --- |
| Infraestrutura como código | Terraform 1.5 ou superior; providers `hashicorp/google` e `hashicorp/google-beta` 6.0 ou superior, `hashicorp/random` |
| Orquestração | GitHub Actions (`workflow_dispatch`), Workload Identity Federation |
| State | Cloud Storage (backend `gcs`), um `prefix` por cliente e stack |
| Projetos e identidade | Resource Manager, IAM, contas de serviço dedicadas por função |
| Aplicação web | Cloud Run, Artifact Registry, Cloud SQL para PostgreSQL, Secret Manager |
| Inteligência artificial | Vertex AI Agent Engine (Reasoning Engine), Vertex AI Search (Discovery Engine) |
| Dados | Firestore (modo nativo), BigQuery, Cloud Logging (sink de atividade do Gemini Enterprise) |
| Mensageria e agendamento | Cloud Tasks, Cloud Scheduler, Pub/Sub |
| Entrega contínua | Cloud Build com gatilhos de Pub/Sub, bucket de releases no Cloud Storage |

## 4. Arquitetura do provisionamento

O fluxo de ponta a ponta envolve o GeApp Manager, o GitHub Actions e o projeto GCP
do cliente:

1. **Solicitação.** O administrador envia o provisionamento de um cliente no GeApp
   Manager, escolhendo a stack e a ação (`plan`, `apply` ou `destroy`).
2. **Segredos.** O GeApp Manager grava os valores secretos no Secret Manager do
   projeto do cliente. Apenas os nomes dos segredos seguem adiante; os valores nunca
   passam pelo Terraform nem são persistidos no banco do GeApp Manager.
3. **Disparo.** O GeApp Manager aciona o workflow
   [`provision.yml`](../../.github/workflows/provision.yml) por `workflow_dispatch`,
   informando o identificador da execução, o *slug* do cliente, o projeto GCP, a
   stack, a ação e as variáveis não secretas em JSON.
4. **Execução.** O workflow valida os parâmetros, autentica no GCP por Workload
   Identity Federation e executa o Terraform em `<ambiente>/stacks/<stack>`, com state em
   `gs://<bucket>/clientes/<client_slug>/<stack>`.
5. **Acompanhamento.** Durante a execução, o script
   [`prod/scripts/log-stream.sh`](prod/scripts/log-stream.sh) envia o log ao GeApp
   Manager em lotes. Ao final, o workflow informa o status e os outputs não sensíveis.
6. **Deploy.** A implantação das aplicações no cliente é feita pelo Cloud Build do
   próprio projeto do cliente, a partir de pacotes publicados no bucket de releases.
   Na primeira execução com `apply`, o próprio workflow submete esse deploy inicial.

A ordem de provisionamento de um novo cliente é: stack `project` (cria o projeto GCP
e a conta `tf-provisioner`) e, em seguida, stack `gemini-enterprise`.

## 5. Estrutura da pasta

```
projects/geapp-manager/
├── README.md                     # Este documento
├── dev/                          # Ambiente de desenvolvimento (geapp-dev-seed-0001), mesma estrutura
│   ├── bootstrap/                #   + bucket de state próprio; README com o passo a passo do dev
│   ├── hosting/                  #   Cloud Run, Cloud SQL e WIF de deploy do manager de dev
│   ├── scripts/
│   └── stacks/                   #   cópia de prod/stacks com o seed de dev
└── prod/                         # Ambiente de produção
    ├── bootstrap/                # Setup único do projeto de controle (aplicação manual)
    │   ├── main.tf
    │   ├── versions.tf
    │   └── README.md             # Procedimento detalhado do bootstrap
    ├── scripts/
    │   └── log-stream.sh         # Envio incremental do log ao GeApp Manager
    └── stacks/                   # Stacks executadas pelo provision.yml
        ├── project/              # Criação do projeto GCP do cliente
        └── gemini-enterprise/    # Aplicações e serviços do cliente
```

O `provision.yml` aceita exclusivamente diretórios de `<ambiente>/stacks/`. Assim, o GeApp
Manager não tem meios de acionar o bootstrap ou executar scripts arbitrários.

O ambiente é escolhido pela branch em que o `provision.yml` roda (ADR 0011 do GeApp
Manager): a `main` usa `prod/` e o GitHub Environment `prod`; a `develop` usa `dev/`
e o Environment `dev`, cujas variáveis apontam para o `geapp-dev-seed-0001`. Cada
Environment só aceita a sua branch, e o Workload Identity de cada seed só aceita a
branch do seu ambiente. Uma mudança de stack é feita e testada em `dev/` na
`develop` e levada a `prod/` na PR para a `main`. Procedimento do dev:
[`dev/bootstrap/README.md`](dev/bootstrap/README.md).

## 6. Stacks

As stacks usam os módulos de [`modules/`](../../modules) pelo caminho local e,
portanto, sempre na versão da branch `main`. O backend é configurado de forma parcial:
o bucket e o `prefix` são informados pelo `provision.yml` em cada execução.

### 6.1 Stack `project`

Cria e prepara o projeto GCP do cliente. É executada como a conta `geapp-seed-sa`.

| Recurso | Finalidade |
| --- | --- |
| Projeto GCP | Criado na pasta de clientes da organização e vinculado à conta de faturamento |
| APIs base | Service Usage, Resource Manager, IAM, IAM Credentials e Secret Manager |
| Conta `tf-provisioner` | Conta que executa as demais stacks do cliente, com os papéis necessários a cada serviço |
| Vínculo com o Workload Identity | Permite que o workflow assuma a `tf-provisioner` |
| Acesso ao bucket de state | Papel `storage.objectAdmin` no bucket de state, para leitura e escrita do state das stacks do cliente |
| Cloud Build e agente de serviço | Pré-requisitos dos gatilhos de deploy |
| Assinatura dos tópicos de release | Permite que o Cloud Build do cliente escute as publicações de cada aplicação |
| Acesso do GeApp Manager aos segredos | Papel `secretmanager.admin` para a conta do GeApp Manager, que grava os segredos do cliente |
| Proprietários do projeto | Concede `roles/owner` às identidades configuradas em `PROJECT_OWNERS` |

Outputs: `project_id`, `project_number` e `tf_provisioner_email`.

A ação `destroy` desta stack é bloqueada pelo workflow: o projeto do cliente e a
`tf-provisioner` nunca são excluídos pelo pipeline. A exclusão de um projeto, quando
necessária, é feita manualmente no console.

### 6.2 Stack `gemini-enterprise`

Deixa o projeto do cliente pronto para o deploy das aplicações. É executada como a
conta `tf-provisioner` do próprio projeto. Organiza-se em três arquivos principais.

**`app.tf` — aplicação web GeApp**

| Recurso | Configuração |
| --- | --- |
| Cloud Run | Serviço da aplicação, de acesso público, com conta de serviço dedicada; nasce com imagem provisória e recebe imagem e variáveis no deploy |
| Artifact Registry | Repositório de imagens das aplicações do cliente |
| Cloud SQL para PostgreSQL | Instância por cliente, com banco `app` e usuário IAM da conta da aplicação |
| BigQuery | Dataset `gemini_enterprise_atividade`, alimentado por sink do Cloud Logging com a atividade de usuários do Gemini Enterprise |
| IAM | Papéis da aplicação: Cloud SQL, Secret Manager, Vertex AI, Firestore e leitura no BigQuery |

**`hyper-agent.tf` — sistema multiagente de engajamento**

| Recurso | Configuração |
| --- | --- |
| Vertex AI Agent Engine | Reasoning Engine `hyper-agent-root` e bucket de staging do pacote do agente |
| Vertex AI Search | Data store `hyper-agent-engajamento`, base de conhecimento do agente de engajamento |
| Firestore | Banco em modo nativo com o perfil dos colaboradores e o mapeamento de espaços do Google Chat |
| BigQuery | Dataset de auditoria das interações |
| Cloud Run `hyper-agent-mensagens-chat` | Recebe webhooks do Google Chat e as tarefas do Cloud Tasks; acesso público, com validação do token do Google Chat na aplicação |
| Cloud Run `hyper-agent-gatilho-scheduler` | Consulta a telemetria de licenças e enfileira as tarefas; acesso restrito às contas do Cloud Scheduler |
| Cloud Tasks | Fila de disparos com uma execução por vez, autenticada por OIDC |
| Cloud Scheduler | Disparos diários às 10h e às 14h (`America/Sao_Paulo`) |

**`cloudbuild.tf` — deploy pelo Cloud Build (opcional)**

Habilitado pela opção `enable_cloud_build`. Cria a conta de deploy e um gatilho do
Cloud Build por aplicação, acionado pelo tópico Pub/Sub de release correspondente.
Cada gatilho obtém o pacote do commit no bucket de releases e executa o
`cloudbuild.yaml` da aplicação. Os valores de configuração do cliente são entregues
como *substitutions*; o projeto do cliente não se conecta ao GitHub.

Outputs principais: URLs dos serviços Cloud Run, nome do Reasoning Engine, bucket de
staging, banco Firestore, data store do Vertex AI Search, dataset do BigQuery, conta
e registro de imagens da aplicação, conexão do Cloud SQL e lista de gatilhos do
Cloud Build.

O arquivo `keep-on-destroy.txt` relaciona endereços de recursos que pertencem ao
projeto do cliente, e não à stack. Em um `destroy`, esses recursos são apenas
removidos do state, sem exclusão no GCP.

## 7. Bootstrap

O bootstrap descreve, em Terraform, a configuração única do projeto de controle
(`geapp-prod-seed-0001`) que viabiliza o pipeline. Ele é aplicado manualmente por um
operador com papel de Owner no projeto de controle, com state no bucket
`gentrop-tfstate`, sob o `prefix` `bootstrap/portal-provisioning` (nome original,
mantido para evitar migração).

### 7.1 Configuração-alvo

| Recurso | Finalidade |
| --- | --- |
| APIs do projeto de controle | Serviços usados como projeto de cota pela `geapp-seed-sa` |
| Workload Identity Federation (provisionamento) | Permite que o `provision.yml` da branch `main` deste repositório assuma a `geapp-seed-sa` |
| Acesso ao bucket de state | Leitura e escrita do state pelas contas do pipeline |
| Workload Identity Federation (releases) | Pool separado, que permite apenas à branch `main` dos repositórios das aplicações publicar releases (conta `release-publisher`) |
| Bucket de releases | Armazena `<app>/<sha>.tar.gz` e o ponteiro `<app>/latest` de cada aplicação |
| Tópicos Pub/Sub `release-<app>` | Anunciam cada nova versão publicada |
| Segredo `cloudbuild-github-token` | Legado da conexão do Cloud Build com o GitHub; não é utilizado pelo fluxo de releases atual e está previsto para remoção |

### 7.2 Situação atual

**A versão atual do bootstrap ainda não foi aplicada.** A configuração em uso foi
feita parcialmente à mão, conforme registrado em
[`prod/bootstrap/README.md`](prod/bootstrap/README.md):

- o Workload Identity do pipeline continua no pool `github-terraform` do projeto
  `geapp-gentrop-prod-0001`, criado pela versão anterior do bootstrap, e a
  `geapp-seed-sa` foi vinculada a ele manualmente;
- os recursos de releases (bucket, tópicos, pool `github-releases` e conta
  `release-publisher`) foram criados manualmente no projeto de controle e serão
  importados pelo `apply` do bootstrap.

A migração para a configuração-alvo exige os passos preparatórios descritos no README
do bootstrap, entre eles retirar do state a `tf-provisioner` do projeto de produção,
para que o `apply` não a exclua.

### 7.3 Papéis concedidos fora do Terraform

A conta `geapp-seed-sa` é criada pelo administrador da organização, que também
concede `roles/resourcemanager.projectCreator` na pasta de clientes e
`roles/billing.user` na conta de faturamento. Esses papéis exigem acesso à pasta e ao
faturamento e, por isso, não fazem parte do bootstrap.

## 8. Pipeline de provisionamento

O workflow [`provision.yml`](../../.github/workflows/provision.yml) implementa as
seguintes salvaguardas:

| Etapa | Comportamento |
| --- | --- |
| Validação | Confere o formato do identificador da execução, do *slug* e do projeto; aceita apenas stacks existentes em `prod/stacks/`; exige que o JSON de variáveis contenha o mesmo projeto e *slug* dos parâmetros |
| Concorrência | Uma execução por cliente e stack por vez; as seguintes aguardam na fila |
| Autenticação | Workload Identity Federation; a stack `project` usa a `geapp-seed-sa`, as demais usam a `tf-provisioner@<project_id>` |
| Proteção | Bloqueia `destroy` da stack `project` |
| Resiliência | Uma nova tentativa automática para erros transitórios conhecidos do GCP (API recém-ativada, nome recém-excluído, propagação de IAM) |
| Primeiro deploy | Após um `apply`, submete os gatilhos do Cloud Build criados e aguarda o resultado |
| Relato | Envia log incremental e, ao final, status e outputs ao GeApp Manager, autenticado pelo token OIDC do próprio workflow |

Os parâmetros recebidos são lidos apenas por variáveis de ambiente, nunca interpolados
diretamente nos comandos, para evitar injeção de comandos.

## 9. Contas de serviço e permissões

| Conta | Onde reside | Responsabilidade |
| --- | --- | --- |
| `geapp-seed-sa` | Projeto de controle | Cria projetos de clientes (stack `project`) |
| `tf-provisioner` | Projeto de cada cliente | Provisiona os serviços do próprio projeto (demais stacks) |
| Conta do GeApp Manager | Projeto em que o GeApp Manager é executado | Grava os segredos no Secret Manager dos clientes (`secretmanager.admin` em cada projeto) |
| Conta de deploy | Projeto de cada cliente | Executa os builds de deploy das aplicações |
| Contas de runtime | Projeto de cada cliente | Uma por serviço Cloud Run e pelo Agent Engine, com o menor conjunto de papéis necessário |

## 10. Configuração no GitHub

O `provision.yml` depende das seguintes configurações. Em prod, vêm do repositório
(o Environment `prod` não tem valores próprios); em dev, do Environment `dev`:

| Tipo | Nome | Conteúdo |
| --- | --- | --- |
| Variável | `WIF_PROVIDER` | Provedor do Workload Identity Federation |
| Variável | `SEED_SA_EMAIL` | E-mail da `geapp-seed-sa` |
| Variável | `TF_STATE_BUCKET` | Bucket de state do Terraform |
| Variável | `PORTAL_URL` | URL pública do GeApp Manager, usada como *audience* do token OIDC e destino do log |
| Variável | `PORTAL_SA_EMAIL` | Conta de serviço do GeApp Manager; enquanto não definida, a stack `project` não concede o acesso aos segredos |
| Variável | `CLIENTS_FOLDER_ID` | Pasta da organização onde os projetos de clientes são criados |
| Variável | `PROJECT_OWNERS` | Identidades que recebem `roles/owner` em cada novo projeto |
| Secret | `CLIENTS_BILLING_ACCOUNT` | Conta de faturamento vinculada aos projetos de clientes |

Os nomes com o prefixo `PORTAL_` antecedem a denominação GeApp Manager e foram
mantidos para não interromper o pipeline.

## 11. Procedimentos operacionais

### 11.1 Alterar uma stack

1. Edite os arquivos em `prod/stacks/<stack>/`.
2. Valide localmente com `terraform fmt` e `terraform validate`.
3. Abra um Pull Request para a `main`, descrevendo o impacto esperado nos clientes.
4. Após o merge, execute um `plan` pelo GeApp Manager em um cliente de teste e
   confirme a ausência de `destroy` ou `replace` inesperados.
5. Aplique nos demais clientes conforme a necessidade. Cada cliente recebe a
   alteração apenas na sua próxima execução.

### 11.2 Alterar um módulo utilizado pelas stacks

As stacks consomem os módulos da `main` diretamente. Uma alteração que modifique ou
recrie recursos existentes deve ser introduzida por uma variável cujo valor padrão
preserve o comportamento atual. Consulte [`modules/README.md`](../../modules/README.md).

### 11.3 Incluir um novo cliente

Nenhuma alteração neste repositório é necessária. O GeApp Manager executa a stack
`project` e, em seguida, a stack `gemini-enterprise`, com o *slug* do novo cliente.

### 11.4 Incluir uma nova stack

1. Crie `prod/stacks/<nova-stack>/` com backend `gcs` parcial (sem bucket e `prefix`).
2. Declare as variáveis que o GeApp Manager envia a todas as stacks.
3. Inclua na `tf-provisioner` (stack `project`) os papéis exigidos pelos novos
   recursos.
4. Registre a nova stack no GeApp Manager.

### 11.5 Alterar o bootstrap

Siga o procedimento de [`prod/bootstrap/README.md`](prod/bootstrap/README.md),
sempre com `terraform plan` revisado antes do `apply`.

## 12. Segurança

- Valores secretos são gravados pelo GeApp Manager diretamente no Secret Manager do
  cliente; o Terraform referencia apenas os nomes.
- Toda autenticação do pipeline no GCP usa Workload Identity Federation, sem chaves
  de conta de serviço. A configuração-alvo do bootstrap restringe a troca de
  credenciais à branch `main` deste repositório.
- Os callbacks ao GeApp Manager são autenticados pelo token OIDC do workflow.
- Cada cliente tem projeto GCP, contas de serviço e state próprios, sem
  compartilhamento de recursos entre clientes.
- A conta de faturamento é tratada como confidencial e armazenada como secret do
  repositório.

## 13. Pontos de atenção

- **Origem do release do GeApp.** O repositório designado para o GeApp é o
  `geapp-portal`, que no momento não possui conteúdo. Os releases continuam sendo
  publicados a partir de `gemini-enteprise-adoption-portal`, conforme
  `app_repositories` em [`prod/bootstrap/main.tf`](prod/bootstrap/main.tf). A troca
  da origem exige atualizar o bootstrap, o Workload Identity de releases e os
  tópicos correspondentes.
- **Registros de decisão.** Os comentários das stacks citam ADRs do GeApp Manager. Na
  branch `main` daquele repositório estão publicados os ADRs 0001 a 0006; os de
  número superior (por exemplo, 0009 e 0010) encontram-se em branches ainda não
  mescladas.
- **Execução de testes.** Alterações nas stacks são exercitadas pelo manager de dev,
  a partir da branch `develop`, antes do merge na `main` (seção 5).
- **Bootstrap pendente.** Enquanto a versão atual do bootstrap não for aplicada, a
  configuração em uso é a descrita na [seção 7.2](#72-situação-atual).
