# Sample: hyper-agent

Configuração de teste que reproduz a infraestrutura completa do
[gentrop-cloud/hyper-agent](https://github.com/gentrop-cloud/hyper-agent), com todos
os módulos conectados entre si, a partir do código local de [`modules/`](../../modules).

## Arquitetura

Cloud Scheduler (10h e 14h) → Cloud Run `hyper-agent-gatilho-scheduler` → Cloud Tasks
`fila-disparos-hyperproject` → Cloud Run `hyper-agent-mensagens-chat` → Vertex AI
Agent Engine, com Firestore e BigQuery de apoio e a infraestrutura de CI/CD da
aplicação (Artifact Registry, Secret Manager para o SMTP e Workload Identity
Federation para o GitHub Actions do repositório `hyper-agent`).

## Recursos criados

| Recurso | Módulo |
| --- | --- |
| APIs Discovery Engine, Cloud Build e App Hub | `google_project_service` |
| Repositório de imagens `hyper-agent` | `artifact-registry` |
| Segredo `SMTP_PASSWORD` | `secret-manager` |
| Workload Identity e conta `hyper-agent-gh-deployer` | `workload-identity` |
| Banco Firestore `hyper-project-db-native` | `firestore-database` |
| Dataset `hyper_agent_auditoria` | `bigquery-dataset` |
| Reasoning Engine `hyper-agent-root`, bucket de staging e conta de runtime | `vertex-ai-agent-engine` |
| Cloud Run de mensagens e de gatilho | `cloud-run` (2) |
| Fila de disparos | `cloud-tasks-queue` |
| Agendamentos das 10h e das 14h | `cloud-scheduler-http` (2) |

## Procedimento

1. Abra o `main.tf` e defina `project_id` em `locals` com o projeto de teste.
2. Informe a senha de aplicativo SMTP em um `terraform.tfvars` nesta pasta (ignorado
   pelo Git):
   ```hcl
   smtp_password = "<senha de aplicativo>"
   ```
3. Autentique-se:
   ```bash
   gcloud auth application-default login
   gcloud config set project <project-id>
   ```
4. Inicialize e aplique:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
   O Reasoning Engine é criado vazio, junto com o bucket de staging, antes do Cloud
   Run de mensagens. Assim, o serviço já nasce com `REASONING_ENGINE_ID`, e nenhum
   pacote provisório do agente é necessário.
5. Cadastre os outputs no repositório `hyper-agent`, conforme o `DEPLOY.md` daquele
   repositório: `workload_identity_provider` e `deployer_service_account_email`
   (Secrets), `reasoning_engine_name` (Secret `REASONING_ENGINE_NAME`),
   `artifact_registry_url` e `agent_engine_staging_bucket` (Variables).
6. A partir daí, o workflow `deploy.yml` do `hyper-agent` publica as imagens dos dois
   Cloud Run e o código do agente (`agent_engines.update`) a cada push relevante na
   `main`.
7. Ao final do teste, remova os recursos com `terraform destroy`.

## Aplicações anteriores a esta versão

Até esta versão, o módulo `agent_engine` era versionado com `count = 0`. Em um state
criado assim, o Cloud Run de mensagens já existe sem `REASONING_ENGINE_ID`, e o módulo
`cloud-run` não altera variáveis de ambiente de serviços existentes. Após o `apply`
que cria o Reasoning Engine, defina a variável manualmente:

```bash
gcloud run services update hyper-agent-mensagens-chat --region=us-central1 \
  --update-env-vars="REASONING_ENGINE_ID=$(terraform output -raw reasoning_engine_name)"
```

## O que este sample não faz

- **Build e deploy do código dos Cloud Run.** Os serviços nascem com a imagem de
  exemplo do módulo `cloud-run`; o deploy é feito pelo `deploy.yml` do `hyper-agent`.
- **Publicação do agente.** O Reasoning Engine nasce sem código; quem publica o agente
  é o `scripts/deploy_agent_engine.py` do `hyper-agent`, pelo CI.
- **Configuração do Google Chat.** O app do Google Chat e os espaços são configurados
  na Google Chat API e no Admin Console, fora do Terraform.
- **Dados iniciais.** A coleção `mapeamento_spaces` do Firestore e as tabelas do
  dataset de auditoria não são criadas; esquemas de tabela podem ser informados pela
  variável `tables` do módulo `bigquery-dataset`.
- **Lista de permissão do piloto.** `PILOT_WHITELIST` não é definida. Sem ela, a lista
  de permissão habilitada por padrão no código (`ENABLE_WHITELIST=true`) bloqueia todos
  os envios, que é o comportamento seguro.
