# Sample: Vertex AI Agent Engine

Configuração de teste do módulo
[`vertex-ai-agent-engine`](../../modules/vertex-ai-agent-engine). Cria, de forma
isolada, um Reasoning Engine do Vertex AI Agent Engine, o bucket de staging do pacote
do agente e a conta de runtime.

## Recursos criados

| Recurso | Nome |
| --- | --- |
| APIs | `aiplatform.googleapis.com` e `storage.googleapis.com` |
| Conta de serviço | `vertex-agent-engine-runtime`, com `roles/aiplatform.user` |
| Bucket de staging | `<project_id>-agent-engine-teste-staging` |
| Reasoning Engine | `agent-engine-teste`, criado sem código |

## Funcionamento

O módulo é chamado sem `package_spec`. Nessa configuração, o Reasoning Engine é
criado vazio no primeiro `apply`, junto com o bucket de staging, sem exigir que um
pacote do agente exista previamente no GCS. O código do agente é publicado depois, pela
esteira de CI da aplicação, com `agent_engines.update`. O módulo ignora alterações na
especificação do engine, de modo que um `apply` posterior não reverte essa publicação.

## Procedimento

1. Abra o `main.tf` e defina `project_id` em `locals` com o projeto de teste.
2. Autentique-se:
   ```bash
   gcloud auth application-default login
   gcloud config set project <project-id>
   ```
3. Inicialize e aplique:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
4. Confira os outputs `reasoning_engine_name` (nome completo do recurso) e
   `staging_bucket_name`.
5. Opcionalmente, publique um agente no engine criado com o Vertex AI SDK
   (`agent_engines.update`, informando `reasoning_engine_name`).
6. Ao final do teste, remova os recursos:
   ```bash
   terraform destroy
   ```

## Variação: apenas o bucket

Para criar somente a conta, o bucket e as APIs, sem o Reasoning Engine, inclua
`create_reasoning_engine = false` no bloco do módulo. Nesse caso, o output
`reasoning_engine_name` é `null`.
