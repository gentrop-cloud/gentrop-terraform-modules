# Exemplo: Vertex AI Agent Engine

Sobe um Reasoning Engine isolado usando o módulo
[`vertex-ai-agent-engine`](../../modules/vertex-ai-agent-engine) — serve só
pra validar o módulo sozinho.

## Antes de aplicar

Diferente dos outros exemplos, **esse não sobe com um `terraform apply`
direto na primeira vez**: o Vertex AI valida e copia o objeto do GCS na hora
de criar o Reasoning Engine, então `package_spec.pickle_object_gcs_uri`
precisa apontar pra um arquivo que já existe de verdade. O `main.tf` já vem
com `count = 0` (desliga só o Reasoning Engine em si) pra você conseguir
aplicar o resto de primeira.

1. Abra o `main.tf` e troque `local.project_id` pelo projeto GCP de destino.
2. Conecte com esse projeto via `gcloud`:
   ```bash
   gcloud auth application-default login
   gcloud config set project SEU_PROJETO_ID
   ```
3. ```bash
   terraform init
   ```
4. ```bash
   terraform apply
   ```
   Com `count = 0`, isso já cria a service account, o bucket de staging e
   habilita as APIs — só não cria o Reasoning Engine ainda.
5. Suba um `agent.pkl` e `requirements.txt` reais pro bucket criado (output
   `staging_bucket_name`) — via Vertex AI SDK
   (`client.agent_engines.create(...)`) ou qualquer pickle válido, só pra
   testar o fluxo de infra.
6. Volte no `main.tf`, troque `count = 0` para `count = 1`, e rode
   `terraform apply` de novo.
7. Se aplicou no projeto errado:
   ```bash
   terraform destroy
   ```

Se você já tem um bundle pronto (esteira de CI da aplicação já rodou pelo
menos uma vez), pode já deixar `count = 1` desde o passo 4.
