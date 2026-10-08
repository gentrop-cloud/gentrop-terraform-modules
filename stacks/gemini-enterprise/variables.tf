# Stack unica aplicada pelo geapp-portal (provision.yml), um state por cliente
# em clientes/<client_slug>/gemini-enterprise. Deixa o projeto do cliente pronto
# para o deploy:
#
# - app.tf:          app do Gemini Enterprise Adoption Portal (Cloud Run com as
#                    env vars, SA de runtime, Artifact Registry, Cloud SQL com
#                    usuario IAM, dataset + sink da atividade do Gemini Enterprise)
# - cloudbuild.tf:   conexao com o GitHub (2a geracao) e trigger de deploy do app
# - hyper-agent.tf:  hyper-agent completo (Agent Engine, Firestore, Tasks, ...)
#
# O Cloud Run do app nasce com uma imagem provisoria e todas as env vars. O
# deploy so troca a imagem (o Terraform ignora a imagem), entao Terraform e
# deploy nao disputam as env vars.
#
# Valores secretos (NEXTAUTH_SECRET, GOOGLE_CLIENT_SECRET, PRIVATE_KEY,
# CLIENT_EMAIL, SMTP_PASSWORD) nunca passam por aqui: o portal grava no Secret
# Manager do cliente e manda so os nomes em secret_env_vars.

variable "project_id" {
  description = "Projeto GCP do cliente"
  type        = string
}

variable "client_slug" {
  description = "Slug do cliente no portal; nomeia o servico do app e a instancia do banco"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "secret_env_vars" {
  description = "Nome => id dos secrets que o portal gravou no Secret Manager do cliente"
  type        = map(string)
  default     = {}
}

# --- opcoes do portal ---------------------------------------------------------

variable "google_client_id" {
  description = "Client ID da credencial OAuth do app GE deste cliente (vai como _GOOGLE_CLIENT_ID no deploy)"
  type        = string
  default     = ""
}

# --- Cloud Build (desligado ate o fluxo de deploy ser definido) ---------------

variable "enable_cloud_build" {
  description = "Cria a conexao com o GitHub e o trigger de deploy do app. Exige as duas variaveis abaixo."
  type        = bool
  default     = false
}

variable "github_app_installation_id" {
  description = "ID da instalacao do app \"Google Cloud Build\" na org do GitHub (TF_VAR via var CLOUDBUILD_GITHUB_INSTALLATION_ID do repo)"
  # string, e nao number: o provision.yml sempre exporta o TF_VAR, vazio quando a
  # var do repo nao existe, e um number vazio quebra o plan.
  type    = string
  default = ""
}

variable "github_token_secret" {
  description = "Secret com o PAT classico (repo, read:user, read:org) da conexao do Cloud Build, ex.: projects/<controle>/secrets/cloudbuild-github-token (TF_VAR via var CLOUDBUILD_GITHUB_TOKEN_SECRET do repo)"
  type        = string
  default     = ""
}

# --- fixos por enquanto ---------------------------------------------------------

variable "app_repository" {
  description = "Repo do app GE que o trigger observa"
  type        = string
  default     = "https://github.com/gentrop-cloud/gemini-enteprise-adoption-portal.git"
}

variable "app_branch" {
  description = "Regex da branch que dispara o deploy"
  type        = string
  default     = "^main$"
}

variable "genguide_project_id" {
  description = "Projeto central da Gentrop com o Firestore do GenGuide (trilhas, videos, playlists), lido pelo app com a SA dos secrets PRIVATE_KEY/CLIENT_EMAIL"
  type        = string
  default     = "genguide-hmol-01"
}

variable "smtp_email" {
  description = "Remetente do fallback de e-mail do hyper-agent"
  type        = string
  default     = "automacao@gentrop.com"
}
