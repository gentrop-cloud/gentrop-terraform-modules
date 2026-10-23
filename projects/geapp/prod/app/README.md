# geapp / prod / app

Stack Terraform da **aplicação web GeApp** no ambiente de produção da Gentrop, projeto
GCP `geapp-gentrop-prod-0001`, região `us-central1`.

## Sumário

1. [Finalidade](#1-finalidade)
2. [Recursos provisionados](#2-recursos-provisionados)
3. [Configuração da aplicação](#3-configuração-da-aplicação)
4. [Arquivos](#4-arquivos)
5. [State](#5-state)
6. [Pré-requisitos](#6-pré-requisitos)
7. [Primeira aplicação](#7-primeira-aplicação)
8. [Operação](#8-operação)
9. [Outputs](#9-outputs)
10. [Pontos de atenção](#10-pontos-de-atenção)

## 1. Finalidade

Esta stack cria toda a infraestrutura necessária para executar a aplicação web GeApp:
o serviço no Cloud Run, o repositório de imagens, o banco de dados PostgreSQL e os
segredos de configuração. A visão geral do projeto está em
[`projects/geapp/README.md`](../../README.md).

## 2. Recursos provisionados

| Recurso | Módulo ou tipo | Configuração |
| --- | --- | --- |
| Repositório de imagens | `artifact-registry` | Repositório Docker da aplicação |
| Instância de banco de dados | `cloud-sql-postgress` | PostgreSQL 18, instância `geapp-gentrop-prod-0001-db`, banco `app`, proteção contra exclusão habilitada |
| Senha do administrador do banco | `random_password` | 24 caracteres, usada pelo módulo do Cloud SQL e armazenada no state |
| Segredos de configuração | `secret-manager` | 17 segredos, com valores gravados por `google_secret_manager_secret_version` |
| Serviço da aplicação | `cloud-run` | Serviço `geapp-gentrop-prod-0001`, com conexão ao Cloud SQL e conta de serviço própria |
| Permissões da aplicação | IAM | `roles/secretmanager.secretAccessor` e `roles/cloudsql.client` |

Os módulos são referenciados pela tag `v1.0.0` deste repositório.

## 3. Configuração da aplicação

A aplicação recebe a configuração por variáveis de ambiente. Duas são passadas como
variáveis comuns, por não serem sensíveis:

| Variável | Origem |
| --- | --- |
| `GOOGLE_CLIENT_ID` | Variável `google_client_id` da stack |
| `NEXTAUTH_URL` | URL determinística do Cloud Run, calculada a partir do número do projeto |

As demais são lidas do Secret Manager, com o mesmo nome do segredo:

| Grupo | Segredos |
| --- | --- |
| Projeto e localização | `PROJECT_ID`, `LOCATION`, `AGENT_PROJECT_ID`, `FIRESTORE_PROJECT_ID`, `SERVICE_NAME_CLIENT` |
| Banco de dados | `DB_USER`, `DB_USER_ENCODED`, `INSTANCE_CONNECTION_NAME` |
| Imagens e identidade | `IMAGE_REGISTRY`, `APP_SERVICE_ACCOUNT`, `IDENTITY_POOL`, `IDENTITY_SA` |
| Integração com o hyper-agent | `HYPER_FIRESTORE_PROJECT_ID`, `HYPER_FIRESTORE_DATABASE_ID`, `RESOURCE_ID` |

A URL do Cloud Run é previsível antes da criação do serviço. Por isso ela pode ser
usada como URI de redirecionamento da credencial OAuth sem dependência circular.

## 4. Arquivos

| Arquivo | Conteúdo |
| --- | --- |
| `main.tf` | Variáveis da credencial OAuth, recursos, chamadas de módulos e outputs |
| `versions.tf` | Versão do Terraform, providers (`google` 5.0 ou superior, `random` 3.5 ou superior) e backend |

## 5. State

| Item | Valor |
| --- | --- |
| Backend | `gcs` |
| Bucket | `gentrop-tfstate` |
| `prefix` | `clientes/geapp-prod` |

O `prefix` mantém o nome anterior à reorganização das pastas, o que evitou a migração
do state. Ele não deve ser alterado nem reutilizado por outra stack.

## 6. Pré-requisitos

1. **Bucket de state.** Criado uma única vez, fora do Terraform:
   ```bash
   gcloud storage buckets create gs://gentrop-tfstate --project=geapp-gentrop-prod-0001 --location=us-central1 --uniform-bucket-level-access
   gcloud storage buckets update gs://gentrop-tfstate --versioning
   ```
2. **Credencial OAuth 2.0.** Não pode ser criada por Terraform, pois o Google não
   oferece API para isso. Crie-a no console, em *APIs & Services > Credentials*,
   usando o output `oauth_redirect_uri` como *Authorized redirect URI*. Informe os
   valores em um `terraform.tfvars` nesta pasta (ignorado pelo Git):
   ```hcl
   google_client_id     = "<client id>.apps.googleusercontent.com"
   google_client_secret = "<client secret>"
   ```
   Os valores padrão declarados em `main.tf` são fictícios e servem apenas para que o
   `apply` seja concluído; o login com Google não funciona até a substituição.
3. **Permissões.** Papéis suficientes no projeto e acesso ao bucket de state.

## 7. Primeira aplicação

### 7.1 A partir de um state local existente

Quando a infraestrutura já tiver sido criada pelo sample
`samples/artifact-registry-secret-manager-cloud-run`, migre o state local para o
backend remoto:

```bash
cp ../../../../samples/artifact-registry-secret-manager-cloud-run/terraform.tfstate .
terraform init -migrate-state
terraform plan
```

Responda `yes` à migração. O `plan` deve indicar **No changes**. Em seguida, apague o
`terraform.tfstate` local desta pasta e não execute mais `apply` pelo sample.

### 7.2 A partir de um projeto vazio

```bash
terraform init
terraform plan
terraform apply
```

Revise o `plan`: em um projeto vazio, devem existir apenas operações de criação.

## 8. Operação

- **Alteração de configuração.** Edite `main.tf`, execute `terraform plan`, abra um
  Pull Request com o resultado e aplique após o merge.
- **Nova versão de módulo.** Atualize `?ref=` nas chamadas de módulo, execute
  `terraform init -upgrade` e revise o `plan` antes do `apply`.
- **Atualização de um segredo.** Altere o valor no `main.tf` (ou no `terraform.tfvars`,
  quando sensível) e aplique; o Terraform cria uma nova versão do segredo, lida pelo
  Cloud Run na próxima revisão do serviço.
- **Acesso direto ao banco.** A lista `authorized_networks` está vazia: somente o Cloud
  Run, pelo Cloud SQL connector, acessa o banco. Para acesso direto, inclua o IP de
  origem com máscara `/32` e remova-o ao final.

## 9. Outputs

| Output | Conteúdo |
| --- | --- |
| `oauth_redirect_uri` | URI de redirecionamento a cadastrar na credencial OAuth |
| `repository_url` | Endereço do repositório de imagens |
| `service_url` | URL do serviço no Cloud Run |
| `service_account_email` | Conta de serviço da aplicação |

## 10. Pontos de atenção

- **Valores provisórios.** Os segredos `IDENTITY_POOL`, `IDENTITY_SA` e `RESOURCE_ID`
  são criados com valores fictícios, pois dependem de recursos de outras stacks
  (Workload Identity do pipeline de deploy e Reasoning Engine do hyper-agent).
  Substitua-os pelos valores reais.
- **Versão do PostgreSQL.** A instância usa `POSTGRES_18`. Alterar `database_version`
  em uma instância existente provoca atualização de versão principal do banco.
- **Imagem e variáveis no Cloud Run.** O módulo `cloud-run` ignora alterações de
  imagem e de variáveis de ambiente após a criação do serviço, para que Terraform e
  pipeline de deploy não disputem a configuração. Consequência: incluir ou remover
  uma variável de ambiente nesta stack não altera um serviço já existente; essa
  mudança deve ser feita pelo deploy da aplicação. Novas versões de segredos já
  referenciados são lidas normalmente a cada nova revisão.
- **Declarações sem uso.** O `main.tf` declara `random_password.nextauth_secret` e o
  local `database_url`, que não são referenciados por nenhum recurso. Podem ser
  removidos em uma limpeza futura.
- **Credenciais do banco.** A senha do administrador fica registrada no state; o
  acesso ao bucket de state deve ser restrito.
