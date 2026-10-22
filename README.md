# gentrop-terraform-modules

Repositório de infraestrutura da Gentrop no Google Cloud, em Terraform. Ele guarda:

- os **módulos** reutilizáveis (Cloud Run, Cloud SQL, Artifact Registry, Secret
  Manager, Workload Identity, Cloud Scheduler, Cloud Tasks, Firestore, BigQuery,
  Vertex AI Agent Engine);
- o **geapp-manager**: as stacks que o manager aplica para cada cliente, o bootstrap
  e o script de log do pipeline;
- os **projetos** aplicados à mão, fora do manager (ex.: geapp prod);
- os **samples** usados para testar cada módulo isolado.

Tudo é montado a partir de `modules/`: as outras pastas só combinam módulos e dizem
em qual projeto GCP e em qual state eles rodam.

## Estrutura

```
modules/                  # módulos reutilizáveis, versionados por tag vX.Y.Z (ver modules/README.md)
samples/                  # bancada de teste dos módulos: source local, state local, sem CI (ver samples/README.md)
projects/
  geapp-manager/prod/     # tudo que o geapp-manager de prod usa para provisionar clientes
    stacks/               #   stacks genéricas, uma por cliente, rodadas pelo provision.yml
      project/            #     cria o projeto GCP do cliente e a SA tf-provisioner
      gemini-enterprise/  #     app + hyper-agent + Cloud Build do cliente
    bootstrap/            #   setup único do provisionamento (WIF, SAs), aplicado à mão
    scripts/              #   log-stream.sh: envia o log do run ao manager
  <projeto>/<ambiente>/<stack>/   # infra fora do manager, aplicada à mão
    geapp/prod/app/       #   app geapp (Cloud Run + Cloud SQL + secrets)
    geapp/prod/agent/     #   hyper-agent do geapp (Scheduler, Tasks, Firestore, BigQuery, Agent Engine)
.github/workflows/        # provision.yml: run disparado pelo manager
```

## Como a infra é aplicada

| Onde | Quem aplica | Módulos | State |
| --- | --- | --- | --- |
| `projects/geapp-manager/prod/stacks/` | geapp-manager → `provision.yml` (`workflow_dispatch`) | caminho local, sempre da `main` | `clientes/<client_slug>/<stack>` |
| `projects/geapp-manager/prod/bootstrap/` | você, uma vez, com Owner no projeto de controle | caminho local | `bootstrap/portal-provisioning` |
| `projects/<projeto>/<ambiente>/<stack>/` | você, com `terraform plan` / `apply` na pasta | tag git (`?ref=vX.Y.Z`) | `prefix` no `versions.tf` da pasta |
| `samples/` | você, para testar um módulo | caminho local | local (`terraform.tfstate`, ignorado pelo git) |

O `provision.yml` só roda pastas de `projects/geapp-manager/prod/stacks/`: o manager manda o
nome do stack (`project`, `gemini-enterprise`) e nunca consegue disparar o bootstrap.

Nos projetos aplicados à mão o módulo vem por tag:

```hcl
source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
```

Assim uma mudança em `modules/` só chega num projeto quando você sobe o `ref` dele.

## Fluxo de manutenção

- **Mudar só um projeto**: edite os `.tf` da pasta em `projects/<projeto>/...` → PR →
  merge em `main` → na pasta, `terraform plan` e `terraform apply`.
- **Mudar um módulo**: edite `modules/<m>` → teste em `samples/` → PR → merge. A
  mudança já chega nas stacks do manager no próximo run; por isso, o que recria ou
  altera recurso existente entra atrás de variável com o default antigo. Para os
  projetos aplicados à mão, crie a tag (`git tag v1.1.0 && git push origin v1.1.0`) e,
  só nos que devem receber a mudança, troque `?ref=v1.0.0` por `?ref=v1.1.0` e rode
  `terraform init -upgrade`.
- **Mudar uma stack do manager**: edite `projects/geapp-manager/prod/stacks/<stack>` → PR →
  merge em `main`. Cada cliente recebe a mudança no próximo run dele pelo manager.
- **Novo projeto ou ambiente**: copie uma pasta para
  `projects/<projeto>/<ambiente>/<stack>`, troque `project_id` e o `prefix` do backend
  (nunca reaproveite um prefix, nem troque o `project_id` de uma pasta já aplicada).
- **Novo cliente do manager**: não passa por aqui; o manager roda o stack `project` e
  depois os outros. Setup inicial em
  [`projects/geapp-manager/prod/bootstrap`](projects/geapp-manager/prod/bootstrap).

## Samples

Um sample por módulo (`samples/<módulo>`) e duas combinações prontas, para testar o
código local antes do PR. O que são, como usar e a lista completa estão em
[`samples/README.md`](samples/README.md).
