# geapp-manager

Infraestrutura que o **GeApp Manager** usa para provisionar clientes do Gemini
Enterprise.

O GeApp Manager é o portal interno da Gentrop para adoção do Gemini Enterprise em
clientes. Ele cadastra o cliente, provisiona a infraestrutura dele (Terraform via
GitHub Actions) e faz o deploy dos apps, com o log de execução ao vivo. Esta pasta
guarda o Terraform que ele roda e o setup único que ele precisa no GCP.

## Repositórios

| Repositório | O que é |
| --- | --- |
| [gentrop-cloud/gentrop-geapp-manager](https://github.com/gentrop-cloud/gentrop-geapp-manager) | o app GeApp Manager (API + SPA): produto, arquitetura e ADRs citados nos comentários desta pasta |
| [gentrop-cloud/geapp-portal](https://github.com/gentrop-cloud/geapp-portal) | o GeApp, app entregue a cada cliente (stack `gemini-enterprise`, `app.tf`) |
| este repositório | stacks, bootstrap e o `provision.yml` que o manager dispara |

O release do GeApp ainda é publicado a partir de
`gentrop-cloud/gemini-enteprise-adoption-portal` (`app_repositories` em
[`prod/bootstrap/main.tf`](prod/bootstrap/main.tf)).

## Como funciona

1. O admin envia o provisionamento de um cliente no manager.
2. O manager grava os valores secretos no Secret Manager do projeto do cliente e
   dispara o [`provision.yml`](../../.github/workflows/provision.yml)
   (`workflow_dispatch`) com o nome do stack, a ação (`plan`, `apply` ou `destroy`) e
   as variáveis não secretas.
3. O `provision.yml` roda `prod/stacks/<stack>` com state em
   `gs://gentrop-tfstate/clientes/<client_slug>/<stack>`. O stack `project` roda
   como a `geapp-seed-sa`; os outros, como a `tf-provisioner` do projeto do cliente.
4. Durante o run, [`prod/scripts/log-stream.sh`](prod/scripts/log-stream.sh) envia o
   log ao manager. No fim, o workflow manda o status e os outputs não sensíveis.
5. O deploy dos apps no cliente é feito pelo Cloud Build, a partir do bucket de
   releases (triggers de Pub/Sub criados pelo stack `gemini-enterprise`).

## Pastas

```
prod/
  stacks/
    project/            # cria o projeto GCP do cliente e a SA tf-provisioner (roda primeiro)
    gemini-enterprise/  # GeApp + hyper-agent + Cloud Build no projeto do cliente
  bootstrap/            # setup único: WIF do GitHub, acesso ao state, bucket e tópicos de release
  scripts/
    log-stream.sh       # envia o log do run ao manager
```

O `provision.yml` só aceita pastas de `prod/stacks/`: o manager nunca consegue
disparar o bootstrap.

## Manutenção

- **Mudar uma stack**: edite `prod/stacks/<stack>` → PR → merge em `main`. Cada cliente
  recebe a mudança no próximo run dele pelo manager. Rode um `plan` num cliente de
  teste antes de um `apply` em cliente real.
- **Mudar um módulo usado aqui**: as stacks usam `modules/` pelo caminho local, sempre
  da `main`. Uma mudança que recria ou altera recurso existente entra atrás de
  variável com o default antigo (ver [`modules/README.md`](../../modules/README.md)).
- **Bootstrap**: aplicado à mão, uma vez, por quem tem Owner no projeto de controle.
  Passo a passo em [`prod/bootstrap/README.md`](prod/bootstrap/README.md).
- **Novo cliente**: não precisa de pasta nova; o manager roda o stack `project` e
  depois o `gemini-enterprise` com o slug do cliente.

## Configuração no GitHub

Vars do repositório lidas pelo `provision.yml`: `WIF_PROVIDER`, `SEED_SA_EMAIL`,
`TF_STATE_BUCKET`, `PORTAL_URL`, `CLIENTS_FOLDER_ID`, `PORTAL_SA_EMAIL`,
`PROJECT_OWNERS`. Secret do repositório: `CLIENTS_BILLING_ACCOUNT`. Os nomes com
`PORTAL_` são anteriores ao nome manager e continuam assim.
