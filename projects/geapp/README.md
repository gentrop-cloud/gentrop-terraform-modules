# geapp

Infraestrutura como código do **GeApp** na instância própria da Gentrop, aplicada
manualmente no projeto GCP `geapp-gentrop-prod-0001`.

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Relação com o GeApp Manager](#2-relação-com-o-geapp-manager)
3. [Repositórios relacionados](#3-repositórios-relacionados)
4. [Componentes da solução](#4-componentes-da-solução)
5. [Tecnologias](#5-tecnologias)
6. [Ambientes e stacks](#6-ambientes-e-stacks)
7. [Versionamento dos módulos](#7-versionamento-dos-módulos)
8. [Pré-requisitos](#8-pré-requisitos)
9. [Procedimentos operacionais](#9-procedimentos-operacionais)
10. [Segurança](#10-segurança)
11. [Pontos de atenção](#11-pontos-de-atenção)

## 1. Visão geral

O GeApp é a solução da Gentrop para acelerar a adoção do Gemini Enterprise nas
organizações. Ela combina duas aplicações complementares:

- **Aplicação web GeApp**: portal de adoção acessado pelos colaboradores, com login
  Google, banco de dados relacional e integração com os dados de uso do Gemini
  Enterprise.
- **hyper-agent**: sistema multiagente que promove o engajamento dos colaboradores de
  forma proativa e reativa, com dicas personalizadas por área e nível de
  conhecimento, acompanhamento do uso real da ferramenta e coleta de casos de
  sucesso, entregues pelo Google Chat ou, na ausência dele, por e-mail.

Esta pasta descreve a instância da Gentrop dessas aplicações. Cada aplicação tem a sua
stack Terraform, com state próprio, de modo que uma pode ser alterada sem qualquer
efeito sobre a outra.

## 2. Relação com o GeApp Manager

O GeApp é entregue aos clientes por dois caminhos distintos, que não compartilham
recursos nem state:

| Caminho | Onde está | Como é aplicado |
| --- | --- | --- |
| Instância da Gentrop | Esta pasta (`projects/geapp/`) | Manualmente, por um operador, com módulos referenciados por tag |
| Instâncias de clientes | Stack `gemini-enterprise` em [`projects/geapp-manager`](../geapp-manager) | Automaticamente, pelo GeApp Manager, com módulos da branch `main` |

As duas configurações descrevem serviços equivalentes, mas evoluem de forma
independente. Uma alteração nesta pasta não alcança os clientes, e vice-versa.

## 3. Repositórios relacionados

| Repositório | Papel |
| --- | --- |
| [gentrop-cloud/geapp-portal](https://github.com/gentrop-cloud/geapp-portal) | Repositório designado para o código da aplicação web GeApp |
| [gentrop-cloud/gemini-enteprise-adoption-portal](https://github.com/gentrop-cloud/gemini-enteprise-adoption-portal) | Código atual da aplicação web (ver [seção 11](#11-pontos-de-atenção)) |
| [gentrop-cloud/hyper-agent](https://github.com/gentrop-cloud/hyper-agent) | Código do hyper-agent: agentes, serviços Cloud Run e pipelines de CI/CD |
| [gentrop-cloud/gentrop-geapp-manager](https://github.com/gentrop-cloud/gentrop-geapp-manager) | Plataforma que provisiona o GeApp nos clientes |

## 4. Componentes da solução

### 4.1 Aplicação web GeApp

| Componente | Serviço do GCP | Função |
| --- | --- | --- |
| Aplicação | Cloud Run | Executa a aplicação web, com conta de serviço própria |
| Imagens | Artifact Registry | Armazena as imagens de contêiner da aplicação |
| Banco de dados | Cloud SQL para PostgreSQL | Banco relacional da aplicação, acessado pelo Cloud SQL connector |
| Configuração | Secret Manager | Segredos e parâmetros lidos pela aplicação como variáveis de ambiente |
| Autenticação | Google OAuth 2.0 | Login dos usuários com contas Google |

### 4.2 hyper-agent

| Componente | Serviço do GCP | Função |
| --- | --- | --- |
| Agendamento | Cloud Scheduler | Dispara os fluxos proativos às 10h e às 14h (`America/Sao_Paulo`) |
| Gatilho | Cloud Run `hyper-agent-gatilho-scheduler` | Consulta a telemetria de licenças, cruza com os perfis e enfileira as interações |
| Telemetria | Discovery Engine API | Informa as licenças ativas e o último acesso de cada usuário ao Gemini Enterprise |
| Distribuição | Cloud Tasks | Entrega as interações uma a uma, controlando a vazão e evitando limites de cota |
| Mensageria | Cloud Run `hyper-agent-mensagens-chat` | Recebe os webhooks do Google Chat e as tarefas, invoca os agentes e entrega as respostas |
| Agentes | Vertex AI Agent Engine | Hospeda o agente orquestrador e os subagentes, com sessões conversacionais persistentes |
| Estado | Firestore (modo nativo) | Perfil dos colaboradores e mapeamento dos espaços do Google Chat |
| Auditoria | BigQuery | Histórico das interações para análise da curva de adoção |
| Canais | Google Chat API e SMTP | Entrega das mensagens; o e-mail é o canal de contingência |

O sistema multiagente é composto por um agente orquestrador, responsável pelo
roteamento e pela entrega final da mensagem, e por três subagentes: engajamento
(dicas, provocações e dúvidas, com apoio de busca no Vertex AI Search), casos de
sucesso (coleta de relatos em texto e vídeo) e perfilamento (registro do perfil do
colaborador no Firestore).

## 5. Tecnologias

### 5.1 Aplicação web GeApp

| Camada | Tecnologia |
| --- | --- |
| Framework | Next.js 16 (App Router) |
| Interface | React 19 e Tailwind CSS 4 |
| Linguagem | TypeScript |
| Gerenciador de pacotes | Bun |
| Autenticação | Google OAuth 2.0, com variáveis de configuração no padrão NextAuth.js (`NEXTAUTH_URL`, `NEXTAUTH_SECRET`) |
| Banco de dados | PostgreSQL 18 no Cloud SQL |

### 5.2 hyper-agent

| Camada | Tecnologia |
| --- | --- |
| Agentes | Python 3.11 e Google Agent Development Kit (ADK), publicados no Vertex AI Agent Engine |
| Serviços HTTP | Python 3.12, Flask, Gunicorn e Functions Framework, em contêineres no Cloud Run |
| Bibliotecas do GCP | Vertex AI SDK, Firestore, BigQuery, Cloud Tasks, Google Auth e Google API Client |
| CI/CD | GitHub Actions (validação, deploy e publicação de release) e Cloud Build, com autenticação por Workload Identity Federation |

### 5.3 Infraestrutura

| Domínio | Tecnologia |
| --- | --- |
| Infraestrutura como código | Terraform 1.5 ou superior, provider `hashicorp/google` 5.0 ou superior, `hashicorp/random` |
| Módulos | Módulos deste repositório, referenciados pela tag `v1.0.0` |
| State | Cloud Storage, bucket `gentrop-tfstate`, um `prefix` por stack |
| Região | `us-central1` |

## 6. Ambientes e stacks

| Ambiente | Stack | Pasta | `prefix` do state | Conteúdo |
| --- | --- | --- | --- | --- |
| `prod` | `app` | [`prod/app`](prod/app) | `clientes/geapp-prod` | Aplicação web GeApp |
| `prod` | `agent` | [`prod/agent`](prod/agent) | `clientes/geapp-prod-hyper-agent` | hyper-agent |

Os `prefix` preservam os nomes adotados antes da reorganização das pastas, o que
dispensou a migração do state. As duas stacks compartilham o projeto GCP
`geapp-gentrop-prod-0001` e a região `us-central1`.

Novos ambientes (por exemplo, `dev` ou `staging`) devem ser criados como pastas irmãs
de `prod/`, cada um com `project_id` e `prefix` próprios.

## 7. Versionamento dos módulos

As duas stacks referenciam os módulos por tag Git:

```hcl
source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
```

Uma nova versão de módulo só é adotada quando a referência `?ref=` da stack é
atualizada, seguida de `terraform init -upgrade` e de um `terraform plan` revisado.
As duas stacks podem adotar versões diferentes, se necessário.

## 8. Pré-requisitos

- Terraform 1.5 ou superior e Google Cloud CLI autenticado
  (`gcloud auth application-default login`).
- Acesso de leitura a este repositório, para o download dos módulos por tag.
- Papéis suficientes no projeto `geapp-gentrop-prod-0001` e acesso ao bucket
  `gentrop-tfstate`.
- Valores que não podem ser automatizados, informados em `terraform.tfvars` (ignorado
  pelo Git): a credencial OAuth da aplicação web e a senha de aplicativo SMTP do
  hyper-agent. Os detalhes estão no README de cada stack.

## 9. Procedimentos operacionais

### 9.1 Alterar uma stack

1. Edite o `main.tf` da stack desejada.
2. Execute `terraform fmt` e `terraform plan` na pasta da stack.
3. Abra um Pull Request anexando o resultado do `plan`.
4. Após o merge, execute `terraform apply` na pasta da stack.

### 9.2 Adotar uma nova versão dos módulos

1. Atualize `?ref=` nas chamadas de módulo da stack.
2. Execute `terraform init -upgrade` e `terraform plan`.
3. Revise com atenção operações de `destroy` e `replace` antes do `apply`.

### 9.3 Criar um novo ambiente

1. Copie a pasta da stack para `projects/geapp/<ambiente>/<stack>/`.
2. Ajuste o `project_id` e defina um `prefix` inédito no `versions.tf`.
3. Revise nomes de recursos que precisem ser únicos no projeto ou globalmente.
4. Execute `terraform init`, `terraform plan` e, após revisão, `terraform apply`.

## 10. Segurança

- Senhas e segredos gerados pelo Terraform ficam apenas no Secret Manager e no state
  remoto, cujo acesso deve ser restrito.
- Valores informados manualmente são declarados como `sensitive` e mantidos fora do
  Git.
- O pipeline de deploy do hyper-agent autentica por Workload Identity Federation,
  restrito ao repositório `gentrop-cloud/hyper-agent`.
- O Cloud SQL é protegido contra exclusão (`deletion_protection`) por padrão.

## 11. Pontos de atenção

- **Repositório da aplicação web.** O repositório designado `geapp-portal` ainda não
  possui conteúdo; o código atual está em `gemini-enteprise-adoption-portal`, que se
  encontra em estágio inicial de desenvolvimento.
- **Valores provisórios.** Algumas configurações são criadas com valores provisórios
  e precisam ser substituídas pelos valores reais após o primeiro `apply`. Os itens
  estão listados no README de cada stack.
