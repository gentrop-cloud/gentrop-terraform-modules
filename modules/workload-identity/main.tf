locals {
  pool_display_name     = coalesce(var.pool_display_name, var.pool_id)
  provider_display_name = coalesce(var.provider_display_name, var.provider_id)

  service_account_email = var.create_service_account ? google_service_account.this[0].email : var.existing_service_account_email
}

resource "google_project_service" "this" {
  for_each = var.enable_apis ? toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]) : []

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Step 3 - Workload Identity Pool
resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = local.pool_display_name
  description               = var.pool_description
  disabled                  = false
}

# Step 4 - OIDC provider for GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = local.provider_display_name
  disabled                           = false

  attribute_mapping   = var.attribute_mapping
  attribute_condition = var.attribute_condition

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = length(var.allowed_audiences) > 0 ? var.allowed_audiences : null
  }
}

# Step 6 - Service account impersonated by GitHub Actions
resource "google_service_account" "this" {
  count = var.create_service_account ? 1 : 0

  project      = var.project_id
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
}

resource "google_project_iam_member" "sa_roles" {
  for_each = toset(var.service_account_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.service_account_email}"
}

# Step 7 - allow the GitHub identity to impersonate the service account
resource "google_service_account_iam_member" "wif_binding" {
  for_each = toset(var.github_repositories)

  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/attribute.repository/${each.value}"
}
