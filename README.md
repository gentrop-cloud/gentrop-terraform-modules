# gentrop-terraform-modules

Repositório de infraestrutura como código (IaC) da Gentrop para o Google Cloud
Platform (GCP), escrito em Terraform. Ele reúne, em um único lugar, os módulos
reutilizáveis que padronizam a criação de recursos na nuvem e as configurações dos
projetos que consomem esses módulos.

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Princípios de organização](#2-princípios-de-organização)
3. [Estrutura do repositório](#3-estrutura-do-repositório)
4. [Componentes](#4-componentes)
5. [Modelos de aplicação](#5-modelos-de-aplicação)
6. [Versionamento dos módulos](#6-versionamento-dos-módulos)
7. [Gerenciamento de state](#7-gerenciamento-de-state)
8. [Pré-requisitos](#8-pré-requisitos)
9. [Procedimentos operacionais](#9-procedimentos-operacionais)
10. [Convenções](#10-convenções)
11. [Segurança](#11-segurança)
12. [Fluxo de contribuição](#12-fluxo-de-contribuição)
13. [Documentação relacionada](#13-documentação-relacionada)

## 1. Visão geral

O repositório cumpre dois papéis complementares:

- **Biblioteca de módulos.** A pasta `modules/` contém um módulo Terraform por serviço
  do GCP. Cada módulo encapsula a configuração adotada pela Gentrop para aquele
  serviço (ativação de APIs, contas de serviço, permissões de IAM e parâmetros
  padrão), de modo que os consumidores informem apenas os dados específicos do seu
  contexto.
- **Catálogo de projetos.** A pasta `projects/` contém as configurações que de fato
  provisionam infraestrutura: cada projeto combina módulos, define em qual projeto do
  GCP eles são aplicados e onde o state do Terraform é armazenado.

Complementarmente, a pasta `samples/` oferece configurações pequenas e independentes
para testar cada módulo de forma isolada, e a pasta `.github/workflows/` contém os
pipelines de automação.

O resultado é uma separação clara entre **o que é reutilizável** (módulos), **o que é
aplicado** (projetos) e **o que serve apenas para validação** (samples).

## 2. Princípios de organização

A estrutura do repositório foi definida para atender aos seguintes princípios:

| Princípio | Como é atendido |
| --- | --- |
| **Reuso** | Toda configuração recorrente de um serviço fica em um único módulo, consumido por todos os projetos. |
| **Isolamento** | Cada projeto e ambiente possui pasta própria e state próprio. Uma alteração em um projeto não afeta os demais. |
| **Controle de versão** | Projetos aplicados manualmente referenciam os módulos por tag Git. Uma alteração em um módulo só alcança um projeto quando a referência daquele projeto é atualizada. |
| **Rastreabilidade** | Toda alteração passa por Pull Request e fica registrada no histórico do Git. |
| **Segurança** | Valores sensíveis, arquivos de state e variáveis locais nunca são versionados. |

## 3. Estrutura do repositório

```
.
├── modules/                          # Biblioteca de módulos reutilizáveis
│   ├── <módulo>/                     #   Um diretório por serviço do GCP
│   └── README.md                     #   Catálogo e guia de uso dos módulos
├── projects/                         # Configurações aplicadas em projetos do GCP
│   └── <projeto>/
│       ├── README.md                 #   Documentação do projeto (quando aplicável)
│       └── <ambiente>/               #   prod, dev, staging, ...
│           └── <stack>/              #   Uma unidade de aplicação (um state)
├── samples/                          # Configurações de teste dos módulos
│   ├── <módulo>/                     #   Um sample por módulo, com o mesmo nome
│   └── README.md                     #   Finalidade e uso dos samples
├── .github/workflows/                # Pipelines de automação (GitHub Actions)
├── .gitignore                        # Exclui state, variáveis locais e artefatos do Terraform
└── README.md                         # Este documento
```

A organização interna de um projeto pode variar conforme a sua forma de aplicação.
Projetos provisionados por pipeline, por exemplo, podem agrupar stacks, scripts de
apoio e configurações de bootstrap sob o diretório do ambiente. Nesses casos, o
README do próprio projeto descreve a sua estrutura.

## 4. Componentes

### 4.1 Módulos (`modules/`)

Um módulo é um conjunto de recursos Terraform que representa um serviço do GCP
configurado segundo o padrão da Gentrop. Os módulos:

- não declaram backend: o consumidor decide em qual state os recursos são registrados;
- não configuram o provider do Google: o consumidor decide em qual projeto e região
  os recursos são criados;
- expõem entradas em `variables.tf` e saídas em `outputs.tf`, todas com descrição;
- possuem `README.md` próprio, com exemplo de uso.

O catálogo completo, o layout de arquivos e os casos de uso estão em
[`modules/README.md`](modules/README.md).

### 4.2 Projetos (`projects/`)

Um projeto reúne as configurações que provisionam a infraestrutura de uma aplicação
ou serviço. O caminho segue o padrão `projects/<projeto>/<ambiente>/<stack>/`, em que:

- **projeto** identifica a aplicação ou o serviço;
- **ambiente** identifica a instância (por exemplo, `prod`, `dev`, `staging`);
- **stack** identifica uma unidade de aplicação independente, com state próprio. Um
  mesmo ambiente pode ter várias stacks, por exemplo uma para a aplicação e outra
  para serviços auxiliares.

Cada stack contém, no mínimo, `main.tf` (recursos e chamadas de módulos) e
`versions.tf` (versão do Terraform, providers e backend).

### 4.3 Samples (`samples/`)

Os samples são configurações independentes, com state local, utilizadas para validar
um módulo em um projeto de teste antes de publicar uma nova versão. Eles não fazem
parte da infraestrutura produtiva e podem ser destruídos a qualquer momento. Detalhes
em [`samples/README.md`](samples/README.md).

### 4.4 Pipelines (`.github/workflows/`)

| Arquivo | Finalidade |
| --- | --- |
| `provision.yml` | Pipeline de provisionamento automatizado. É acionado por `workflow_dispatch` com o nome da stack, a ação (`plan`, `apply` ou `destroy`) e as variáveis da execução, e roda o Terraform com autenticação por Workload Identity Federation. O README do projeto que utiliza o pipeline descreve as stacks aceitas e a configuração necessária. |
| `terraform-apply.yml` | Workflow reutilizável (`workflow_call`) que executa `terraform init` e `terraform apply` em um diretório informado. |

## 5. Modelos de aplicação

Uma configuração pode ser aplicada de três formas. A forma determina como os módulos
são referenciados e onde o state é armazenado.

| Modelo | Quem aplica | Referência aos módulos | State |
| --- | --- | --- | --- |
| **Manual** | Um operador, com `terraform plan` e `terraform apply` na pasta da stack | Tag Git (`?ref=vX.Y.Z`) | Bucket GCS, com `prefix` definido no `versions.tf` da stack |
| **Pipeline** | O `provision.yml`, acionado por uma aplicação ou por um operador | Caminho local (`../modules/...`), sempre a partir da branch `main` | Bucket GCS, com `prefix` derivado pelo pipeline dos parâmetros da execução |
| **Sample** | Um desenvolvedor, para testar um módulo | Caminho local (`../../modules/...`) | Local (`terraform.tfstate`, ignorado pelo Git) |

Consequência importante: **projetos aplicados por pipeline recebem imediatamente
qualquer alteração de módulo mesclada na `main`**, pois não utilizam tag. Por isso,
alterações de comportamento em módulos devem preservar o comportamento anterior como
padrão (ver [seção 9.2](#92-alterar-um-módulo-e-propagar-a-alteração)).

Exemplo de referência por tag, usada no modelo manual:

```hcl
module "app" {
  source = "git::https://github.com/gentrop-cloud/gentrop-terraform-modules.git//modules/cloud-run?ref=v1.0.0"
  # ...
}
```

## 6. Versionamento dos módulos

Os módulos são versionados em conjunto, por tags do repositório no formato
[Semantic Versioning](https://semver.org/lang/pt-BR/) (`vMAJOR.MINOR.PATCH`):

| Componente | Quando incrementar | Exemplo |
| --- | --- | --- |
| **MAJOR** | Alteração incompatível: remoção ou renomeação de variável, mudança que recria recursos existentes | `v1.4.2` → `v2.0.0` |
| **MINOR** | Nova funcionalidade compatível: nova variável com valor padrão que preserva o comportamento anterior | `v1.4.2` → `v1.5.0` |
| **PATCH** | Correção compatível, sem alteração de interface | `v1.4.2` → `v1.4.3` |

Regras:

- Uma tag é criada sobre um commit revisado, preferencialmente já mesclado na `main`,
  e nunca é movida depois de consumida por um projeto.
- O projeto escolhe quando adotar uma nova versão. Projetos que permanecem na versão
  anterior não sofrem qualquer alteração.
- Ao adotar uma nova versão, execute `terraform init -upgrade` para baixar o código
  da nova tag.

## 7. Gerenciamento de state

O state do Terraform registra a correspondência entre a configuração e os recursos
existentes no GCP. Sua integridade é crítica.

- **Armazenamento.** Stacks manuais e de pipeline usam o backend `gcs`. O bucket deve
  ter versionamento de objetos habilitado, para permitir a recuperação de versões
  anteriores do state.
- **Isolamento.** Cada stack usa um `prefix` exclusivo dentro do bucket. O `prefix` é
  o que impede que uma execução enxergue (e eventualmente destrua) recursos de outra
  stack. **Nunca reutilize um `prefix`.**
- **Bloqueio.** O backend `gcs` bloqueia o state durante cada execução, impedindo
  aplicações concorrentes sobre a mesma stack.
- **Imutabilidade do destino.** Nunca altere o `project_id` de uma stack já aplicada.
  Para outro projeto do GCP, crie uma nova pasta.
- **Renomeação de pastas.** O nome da pasta e o `prefix` são independentes. Uma pasta
  pode ser renomeada mantendo o `prefix` original, sem migração. Para alterar o
  `prefix`, use `terraform init -migrate-state` e confirme, com `terraform plan`, que
  não há alterações.

## 8. Pré-requisitos

| Requisito | Versão ou detalhe |
| --- | --- |
| Terraform | 1.5 ou superior |
| Provider `hashicorp/google` | 5.0 ou superior; algumas stacks exigem versões mais recentes (ver o `versions.tf` de cada uma) |
| Google Cloud CLI (`gcloud`) | Para autenticação local |
| Git | Com acesso de leitura a este repositório, necessário para baixar módulos por tag |
| Permissões no GCP | Papéis suficientes no projeto de destino e acesso ao bucket de state |

Autenticação local:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <project-id>
```

## 9. Procedimentos operacionais

### 9.1 Alterar a configuração de um único projeto

Aplica-se quando a alteração utiliza parâmetros que o módulo já oferece (por exemplo,
memória de um serviço, variáveis de ambiente ou papéis de uma conta de serviço).

1. Edite o `main.tf` da stack em `projects/<projeto>/<ambiente>/<stack>/`.
2. Abra um Pull Request e anexe a saída de `terraform plan`.
3. Após a aprovação e o merge, execute `terraform apply` na pasta da stack.

Nenhum outro projeto é afetado.

### 9.2 Alterar um módulo e propagar a alteração

Aplica-se quando a alteração muda o comportamento do módulo.

1. Altere o módulo em `modules/<módulo>/`.
2. Preserve o comportamento anterior como padrão: uma alteração que recria ou modifica
   recursos existentes deve ficar atrás de uma variável cujo valor padrão mantém o
   comportamento atual.
3. Valide a alteração no sample correspondente, em `samples/<módulo>/`.
4. Atualize o `README.md` do módulo.
5. Abra um Pull Request. Após o merge, crie a tag conforme a [seção 6](#6-versionamento-dos-módulos):
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
6. Em cada projeto manual que deve receber a alteração, atualize a referência
   `?ref=` para a nova tag, execute `terraform init -upgrade` e `terraform plan`, e
   aplique após revisão.

Projetos aplicados por pipeline recebem a alteração na próxima execução, a partir da
`main`.

### 9.3 Criar um novo projeto ou ambiente

1. Crie a pasta `projects/<projeto>/<ambiente>/<stack>/`. Uma stack existente pode
   servir de ponto de partida.
2. Defina o `project_id` de destino e um `prefix` de backend inédito no `versions.tf`.
3. Referencie os módulos pela tag vigente.
4. Documente o projeto em `projects/<projeto>/README.md`.
5. Execute `terraform init` e `terraform plan`, e aplique após revisão.

### 9.4 Criar um novo módulo

1. Crie `modules/<módulo>/` com o layout descrito em [`modules/README.md`](modules/README.md).
2. Crie o sample correspondente em `samples/<módulo>/`.
3. Inclua o módulo no catálogo de `modules/README.md` e o sample em
   `samples/README.md`.
4. Após o merge, publique uma nova versão MINOR.

### 9.5 Projetos aplicados por pipeline

Projetos desse tipo não são aplicados manualmente. Suas stacks são executadas pelo
`provision.yml`, que valida a stack solicitada, autentica no GCP e registra o state
em um `prefix` derivado dos parâmetros da execução, de modo que cada combinação de
destino e stack mantenha o seu próprio state. Alterações nas stacks seguem o
fluxo de Pull Request e entram em vigor na próxima execução após o merge na `main`.
Recomenda-se executar um `plan` em um ambiente de teste antes de um `apply` em
ambiente produtivo. A configuração específica (variáveis e secrets do repositório,
contas de serviço e bootstrap) está no README do projeto correspondente.

## 10. Convenções

- **Nomes.** Diretórios de módulos, samples e stacks em minúsculas, separados por
  hífen (`kebab-case`). O sample de um módulo tem o mesmo nome do módulo.
- **Layout de módulo.** `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` e
  `README.md`. Arquivos adicionais são aceitos quando organizam responsabilidades
  distintas.
- **Variáveis.** Toda variável declara `type` e `description`. Valores padrão devem
  ser seguros e preservar o comportamento existente.
- **Formatação e validação.** Antes de abrir um Pull Request, execute
  `terraform fmt -recursive` e `terraform validate` nas pastas alteradas.
- **Comentários.** Explicam o motivo de uma decisão que o código não deixa evidente,
  e não o que o código faz.
- **Documentação.** Toda alteração de interface de um módulo é refletida no README
  do módulo no mesmo Pull Request.

## 11. Segurança

- **Arquivos não versionados.** O `.gitignore` exclui `*.tfstate`, `*.tfvars`,
  `*.tfvars.json`, `.terraform/`, arquivos de override e de configuração da CLI.
  Valores sensíveis locais devem ficar em `terraform.tfvars`, que nunca é commitado.
- **Segredos.** Valores secretos são armazenados no Secret Manager. O módulo
  `secret-manager` cria apenas os containers dos segredos; os valores são gravados por
  processo próprio e referenciados pelos serviços por nome.
- **Autenticação em automações.** Pipelines autenticam no GCP por Workload Identity
  Federation, sem chaves de conta de serviço.
- **Proteção contra exclusão.** Módulos de recursos críticos expõem a variável
  `deletion_protection`. Nos que armazenam dados, como o `cloud-sql-postgress`, ela é
  habilitada por padrão; em outros, como o `cloud-run`, é desabilitada por padrão e
  deve ser habilitada nos ambientes produtivos.
- **Revisão de plano.** Nenhum `apply` em ambiente produtivo deve ocorrer sem a
  revisão prévia do `terraform plan`, com atenção especial a operações de `destroy` e
  `replace`.

## 12. Fluxo de contribuição

1. Crie uma branch a partir da `main`.
2. Implemente a alteração seguindo as [convenções](#10-convenções).
3. Valide com `terraform fmt`, `terraform validate` e, quando aplicável,
   `terraform plan` ou um sample.
4. Abra um Pull Request para a `main` descrevendo o objetivo, o impacto em cada
   projeto e o resultado do `plan`.
5. Após a aprovação, faça o merge. Se a alteração envolver módulos, publique a nova
   tag e atualize os projetos manuais que devem adotá-la.

Checklist do Pull Request:

- [ ] `terraform fmt` e `terraform validate` sem erros nas pastas alteradas
- [ ] `terraform plan` revisado, sem `destroy` ou `replace` inesperados
- [ ] Comportamento anterior preservado como padrão nos módulos alterados
- [ ] READMEs atualizados (módulo, sample e projeto, quando aplicável)

## 13. Documentação relacionada

| Documento | Conteúdo |
| --- | --- |
| [`modules/README.md`](modules/README.md) | Catálogo dos módulos, layout, uso e casos de uso de manutenção |
| [`samples/README.md`](samples/README.md) | Finalidade dos samples e lista disponível |
| `projects/<projeto>/README.md` | Documentação específica de cada projeto |
| `modules/<módulo>/README.md` | Exemplo de uso, variáveis e saídas de cada módulo |
