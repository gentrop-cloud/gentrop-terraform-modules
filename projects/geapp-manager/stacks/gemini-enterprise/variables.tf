# Stack unica aplicada pelo geapp-manager (provision.yml), um state por cliente
# em clientes/<client_slug>/gemini-enterprise. Deixa o projeto do cliente pronto
# para o deploy:
#
# - app.tf:          app do Gemini Enterprise Adoption Portal (Cloud Run com as
#                    env vars, SA de runtime, Artifact Registry, Cloud SQL com
#                    usuario IAM, dataset + sink da atividade do Gemini Enterprise)
# - cloudbuild.tf:   um trigger de Pub/Sub por app, que faz o deploy a partir do bucket de releases
# - hyper-agent.tf:  hyper-agent completo (Agent Engine, Firestore, Tasks, ...)
#
# Os Cloud Run nascem com uma imagem provisoria e sem env vars. O deploy (Cloud
# Build) aplica imagem e env vars, e o Terraform ignora as duas, entao Terraform
# e deploy nao disputam a configuracao (ADR 0009 do geapp-manager).
#
# Valores secretos (NEXTAUTH_SECRET, GOOGLE_CLIENT_SECRET, PRIVATE_KEY,
# CLIENT_EMAIL, SMTP_PASSWORD) nunca passam por aqui: o manager grava no Secret
# Manager do cliente e manda so os nomes em secret_env_vars.

variable "project_id" {
  description = "Projeto GCP do cliente"
  type        = string
}

variable "client_slug" {
  description = "Slug do cliente no manager; nomeia o servico do app e a instancia do banco"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "secret_env_vars" {
  description = "Nome => id dos secrets que o manager gravou no Secret Manager do cliente"
  type        = map(string)
  default     = {}
}

# --- opcoes do manager ---------------------------------------------------------

variable "google_client_id" {
  description = "Client ID da credencial OAuth do app GE deste cliente (vai como _GOOGLE_CLIENT_ID no deploy)"
  type        = string
  default     = ""
}

# --- Cloud Build -----------------------------------------------------------------

variable "enable_cloud_build" {
  description = "Opcao \"Deploy pelo Cloud Build\" do manager: cria um trigger de Pub/Sub por app, e o provision.yml faz o primeiro deploy"
  type        = bool
  default     = false
}

# --- fixos por enquanto ---------------------------------------------------------

variable "release_bucket" {
  description = "Bucket de releases no seed (bootstrap), com <app>/<sha>.tar.gz e o ponteiro <app>/latest"
  type        = string
  default     = "geapp-prod-seed-0001-releases"
}

variable "release_topics" {
  description = "Topico de release de cada app no seed (bootstrap); a chave e a pasta do app no bucket"
  type        = map(string)
  default = {
    geapp       = "projects/geapp-prod-seed-0001/topics/release-geapp"
    hyper-agent = "projects/geapp-prod-seed-0001/topics/release-hyper-agent"
  }
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
