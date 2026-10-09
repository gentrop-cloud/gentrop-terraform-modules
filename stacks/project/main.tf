# Cria o projeto GCP do cliente, na pasta de clientes e ligado ao faturamento.
# Roda antes de qualquer outro stack, com state em clientes/<client_slug>/project.
# Os servicos do projeto sao habilitados pelo stack de provisionamento, nao aqui.
#
# Depende do bootstrap/portal-provisioning conceder ao tf-provisioner, na pasta,
# projectCreator e os papeis dos stacks: o Owner de criador e removido abaixo,
# e daqui em diante a SA so tem o que herda da pasta.

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
  description = "Conta de faturamento dos clientes (TF_VAR via var CLIENTS_BILLING_ACCOUNT do repo)"
  type        = string
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

# Quem cria um projeto ganha roles/owner nele. A SA nao deve ser dona de todo
# cliente: fica so com os papeis herdados da pasta.
data "google_client_openid_userinfo" "me" {}

resource "google_project_iam_member_remove" "creator_owner" {
  project = google_project.this.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${data.google_client_openid_userinfo.me.email}"
}

output "project_id" {
  value = google_project.this.project_id
}

output "project_number" {
  value = google_project.this.number
}
