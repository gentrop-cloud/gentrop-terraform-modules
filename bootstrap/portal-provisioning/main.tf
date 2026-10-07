variable "control_project_id" {
  description = "Projeto que guarda o bucket de state, o WIF do GitHub e a SA tf-provisioner"
  type        = string
  default     = "geapp-gentrop-prod-0001"
}

variable "state_bucket" {
  description = "Bucket de state compartilhado (ja existente)"
  type        = string
  default     = "gentrop-tfstate"
}

variable "client_project_ids" {
  description = "Projetos de clientes que o portal pode provisionar. Adicione um projeto aqui no onboarding do cliente."
  type        = list(string)
  default     = []
}

variable "portal_service_account_email" {
  description = "SA de runtime do geapp-portal (grava secrets no projeto do cliente). null enquanto o portal nao estiver no Cloud Run."
  type        = string
  default     = null
}

locals {
  repository = "gentrop-cloud/gentrop-terraform-modules"

  # O que os stacks em stacks/ criam no projeto do cliente. Mantenha em sincronia
  # quando um stack passar a usar um servico novo.
  tf_client_roles = [
    "roles/serviceusage.serviceUsageAdmin",  # habilitar APIs
    "roles/iam.serviceAccountAdmin",         # criar SAs de runtime
    "roles/iam.serviceAccountUser",          # anexar SA ao Cloud Run (actAs)
    "roles/resourcemanager.projectIamAdmin", # papeis das SAs de runtime
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/secretmanager.viewer", # o stack so referencia secrets que o portal criou
    "roles/datastore.owner",      # hyper-agent: Firestore
    "roles/bigquery.admin",       # hyper-agent: dataset de auditoria
    "roles/cloudtasks.admin",     # hyper-agent
    "roles/cloudscheduler.admin", # hyper-agent
    "roles/aiplatform.admin",     # hyper-agent: Agent Engine
    "roles/storage.admin",        # hyper-agent: bucket de staging
  ]

  tf_bindings = { for pair in setproduct(var.client_project_ids, local.tf_client_roles) : "${pair[0]}/${pair[1]}" => {
    project = pair[0]
    role    = pair[1]
  } }
}

# As credenciais da tf-provisioner usam o projeto de controle como projeto de
# cota. Sem estas APIs aqui, chamadas em projetos de clientes falham com 403
# "API has not been used in project <controle>" (ex.: IAM de projeto).
resource "google_project_service" "control" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
  ])

  project            = var.control_project_id
  service            = each.value
  disable_on_destroy = false
}

# Pool e SA proprios: nao reaproveita o github-actions-pool / github-deployer do
# examples/github-actions-wif, que serve ao deploy de apps e tem outros papeis.
module "wif" {
  source = "../../modules/workload-identity"

  project_id  = var.control_project_id
  pool_id     = "github-terraform"
  provider_id = "terraform-modules"

  # So o provision.yml da main deste repo troca token por credencial GCP.
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository == \"${local.repository}\" && assertion.ref == \"refs/heads/main\""

  service_account_id           = "tf-provisioner"
  service_account_display_name = "Terraform do portal de provisionamento"
  service_account_roles        = []
  github_repositories          = [local.repository]
}

resource "google_storage_bucket_iam_member" "tf_state" {
  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${module.wif.service_account_email}"
}

resource "google_project_iam_member" "tf_client" {
  for_each = local.tf_bindings

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${module.wif.service_account_email}"
}

resource "google_project_iam_member" "portal_secrets" {
  for_each = var.portal_service_account_email == null ? toset([]) : toset(var.client_project_ids)

  project = each.value
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${var.portal_service_account_email}"
}

output "workload_identity_provider" {
  description = "Vai na var WIF_PROVIDER do repo"
  value       = module.wif.workload_identity_provider
}

output "service_account_email" {
  description = "Vai na var TF_SA_EMAIL do repo"
  value       = module.wif.service_account_email
}
