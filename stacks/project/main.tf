# Cria o projeto GCP do cliente, na pasta de clientes e ligado ao faturamento,
# e dentro dele a SA tf-provisioner que roda os outros stacks deste cliente.
# Roda antes de qualquer outro stack, com state em clientes/<client_slug>/project.
#
# Roda como a geapp-seed-sa (projeto seed), que so cria projetos: na pasta ela
# tem projectCreator, e na conta de faturamento, billing.user. Os servicos do
# cliente sao provisionados pela tf-provisioner do proprio projeto.

variable "project_id" {
  description = "ID do projeto GCP a criar (unico no mundo)"
  type        = string
}

variable "client_slug" {
  description = "Slug do cliente no portal"
  type        = string
}

variable "client_name" {
  description = "Nome exibido do projeto"
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "Pasta de clientes (TF_VAR via var CLIENTS_FOLDER_ID do repo)"
  type        = string
}

variable "billing_account" {
  description = "Conta de faturamento dos clientes (TF_VAR via secret CLIENTS_BILLING_ACCOUNT do repo)"
  type        = string
  # Confidencial: fora do plan e do log que vai ao portal. Fica so no state.
  sensitive = true
}

# Enviadas pelo portal a todo stack; este nao usa. Declaradas para o Terraform
# nao avisar de variavel nao declarada no portal.auto.tfvars.json.
variable "region" {
  type    = string
  default = "us-central1"
}

variable "secret_env_vars" {
  type    = map(string)
  default = {}
}

variable "wif_provider" {
  description = "Provider do WIF no projeto seed (TF_VAR via var WIF_PROVIDER do repo)"
  type        = string
}

variable "state_bucket" {
  description = "Bucket de state (TF_VAR via var TF_STATE_BUCKET do repo)"
  type        = string
}

variable "portal_service_account_email" {
  description = "SA de runtime do geapp-portal, que grava os secrets no projeto do cliente (TF_VAR via var PORTAL_SA_EMAIL do repo). Vazio enquanto o portal nao estiver no Cloud Run."
  type        = string
  default     = ""
}

variable "github_token_secret" {
  description = "Secret do PAT do Cloud Build no projeto seed (TF_VAR via var CLOUDBUILD_GITHUB_TOKEN_SECRET do repo). Vazio sem Cloud Build."
  type        = string
  default     = ""
}

locals {
  repository = "gentrop-cloud/gentrop-terraform-modules"
  wif_pool   = regex("^(.+)/providers/[^/]+$", var.wif_provider)[0]

  # O que os stacks em stacks/ criam no projeto do cliente. Mantenha em sincronia
  # quando um stack passar a usar um servico novo.
  tf_provisioner_roles = [
    "roles/serviceusage.serviceUsageAdmin",  # habilitar APIs
    "roles/iam.serviceAccountAdmin",         # criar SAs de runtime
    "roles/iam.serviceAccountUser",          # anexar SA ao Cloud Run (actAs)
    "roles/resourcemanager.projectIamAdmin", # papeis das SAs de runtime
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/secretmanager.viewer",       # o stack so referencia secrets que o portal criou
    "roles/datastore.owner",            # hyper-agent: Firestore
    "roles/bigquery.admin",             # hyper-agent: dataset de auditoria
    "roles/cloudtasks.admin",           # hyper-agent
    "roles/cloudscheduler.admin",       # hyper-agent
    "roles/aiplatform.admin",           # hyper-agent: Agent Engine
    "roles/storage.admin",              # hyper-agent: bucket de staging
    "roles/cloudsql.admin",             # app: instancia e GRANTs pelo Cloud SQL connector
    "roles/cloudbuild.connectionAdmin", # app: conexao com o GitHub
    "roles/cloudbuild.builds.editor",   # app: trigger de deploy
    "roles/logging.configWriter",       # app: sink da atividade do Gemini Enterprise
  ]

  # O que a geapp-seed-sa mantem no projeto depois de largar o Owner: so o
  # necessario para os proximos runs deste stack lerem e ajustarem a tf-provisioner.
  seed_roles = [
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
  ]
}

resource "google_project" "this" {
  project_id      = var.project_id
  name            = var.client_name != "" ? substr(var.client_name, 0, 30) : var.project_id
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = { client = var.client_slug }

  # Segunda trava: o destroy pelo portal ja tira o projeto do state antes do plan
  # (keep-on-destroy.txt). Isto barra um `terraform destroy` rodado a mao.
  deletion_policy = "PREVENT"
}

# A tf-provisioner usa o proprio projeto como projeto de cota: sem estas APIs,
# o primeiro stack falha antes de conseguir habilitar as dele. Secret Manager
# porque o portal grava os secrets antes do primeiro stack.
resource "google_project_service" "base" {
  for_each = toset([
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "tf_provisioner" {
  project      = google_project.this.project_id
  account_id   = "tf-provisioner"
  display_name = "Terraform do portal de provisionamento"

  depends_on = [google_project_service.base]
}

resource "google_project_iam_member" "tf_provisioner" {
  for_each = toset(local.tf_provisioner_roles)

  project = google_project.this.project_id
  role    = each.value
  member  = google_service_account.tf_provisioner.member
}

# So o provision.yml da main deste repo assume a tf-provisioner (condicao do provider).
resource "google_service_account_iam_member" "wif" {
  service_account_id = google_service_account.tf_provisioner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.wif_pool}/attribute.repository/${local.repository}"
}

# shortcut: acesso ao bucket inteiro, como a SA unica tinha antes. Restringir a
# clientes/<slug>/ exige condicao IAM que tambem cubra o list do backend GCS.
resource "google_storage_bucket_iam_member" "tf_state" {
  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = google_service_account.tf_provisioner.member
}

resource "google_secret_manager_secret_iam_member" "github_token" {
  count = var.github_token_secret == "" ? 0 : 1

  secret_id = var.github_token_secret
  role      = "roles/secretmanager.admin"
  member    = google_service_account.tf_provisioner.member
}

resource "google_project_iam_member" "portal_secrets" {
  count = var.portal_service_account_email == "" ? 0 : 1

  project = google_project.this.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${var.portal_service_account_email}"
}

data "google_client_openid_userinfo" "me" {}

resource "google_project_iam_member" "seed" {
  for_each = toset(local.seed_roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${data.google_client_openid_userinfo.me.email}"
}

# Quem cria um projeto ganha roles/owner nele. A geapp-seed-sa nao deve ser dona
# de todo cliente: larga o Owner depois de montar a tf-provisioner.
resource "google_project_iam_member_remove" "creator_owner" {
  project = google_project.this.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${data.google_client_openid_userinfo.me.email}"

  depends_on = [
    google_project_iam_member.seed,
    google_project_iam_member.tf_provisioner,
    google_project_iam_member.portal_secrets,
    google_service_account_iam_member.wif,
  ]
}

output "project_id" {
  value = google_project.this.project_id
}

output "project_number" {
  value = google_project.this.number
}

output "tf_provisioner_email" {
  value = google_service_account.tf_provisioner.email
}
