# cloud-scheduler-http

Cria um job de Cloud Scheduler que dispara uma requisição HTTP autenticada via
OIDC (service account própria, create-or-reuse).

Um job = uma instância do módulo. Para múltiplos horários (ex: 10h00 e
14h00), instancie o módulo mais de uma vez.

## Uso

```hcl
module "disparo_10h" {
  source     = "../../modules/cloud-scheduler-http"
  project_id = "seu-projeto-id"
  region     = "us-central1"
  name       = "hyper-agent-disparo-10h"
  schedule   = "0 10 * * *"
  time_zone  = "America/Sao_Paulo"
  uri        = module.hyper_agent_gatilho.service_url
}

module "disparo_14h" {
  source     = "../../modules/cloud-scheduler-http"
  project_id = "seu-projeto-id"
  region     = "us-central1"
  name       = "hyper-agent-disparo-14h"
  schedule   = "0 14 * * *"
  time_zone  = "America/Sao_Paulo"
  uri        = module.hyper_agent_gatilho.service_url
}
```

Depois, adicione a service account do job em `invoker_members` do Cloud Run
alvo (módulo `cloud-run`):

```hcl
invoker_members = [
  "serviceAccount:${module.disparo_10h.service_account_email}",
  "serviceAccount:${module.disparo_14h.service_account_email}",
]
```
