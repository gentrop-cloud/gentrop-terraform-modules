# vertex-ai-agent-engine

Cria a infraestrutura de apoio (service account, bucket de staging) e
registra o recurso `google_vertex_ai_reasoning_engine` (Vertex AI Agent
Engine / Reasoning Engine).

## Uso

```hcl
module "agent_engine" {
  source     = "../../modules/vertex-ai-agent-engine"
  project_id = "seu-projeto-id"
  region     = "us-central1"

  display_name         = "hyper-agent-root"
  staging_bucket_name  = "seu-projeto-id-agent-engine-staging"

  service_account_roles = [
    "roles/aiplatform.user",
  ]

  package_spec = {
    pickle_object_gcs_uri = "gs://seu-projeto-id-agent-engine-staging/agent.pkl"
    requirements_gcs_uri  = "gs://seu-projeto-id-agent-engine-staging/requirements.txt"
  }
}
```

## Bundle do agente e CI

O bundle (pickle do `root_agent` + subagentes, `requirements.txt`) é
construído e enviado ao bucket de staging pelo pipeline de CI da aplicação
via Vertex AI SDK (`client.agent_engines.create`/`.update`) — **não por este
módulo**. O Terraform só registra/atualiza o recurso apontando pros URIs do
GCS; por isso o campo `spec` inteiro usa `lifecycle.ignore_changes`, mesmo
padrão usado para `image` no módulo `cloud-run`: assim, redeploys do CI não
são revertidos no próximo `terraform apply`.

## Memory Bank / retenção de sessões

Este módulo não configura `context_spec` (Memory Bank) — decisão adiada até
confirmar se a retenção de 30 dias das sessões é memória de longo prazo do
Agent Engine (`context_spec.memory_bank_config.ttl_config`) ou um TTL de
sessão tratado a nível de aplicação. Adicione um bloco `context_spec` ao
`main.tf` quando isso for confirmado.
