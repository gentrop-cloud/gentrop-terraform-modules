variable "project_id" {
  description = "GCP project id where the pool, provider and service account live."
  type        = string
}

variable "enable_apis" {
  description = "Enable the APIs required by Workload Identity Federation (iam, iamcredentials, sts)."
  type        = bool
  default     = true
}

# --- Pool ---

variable "pool_id" {
  description = "Workload Identity Pool id."
  type        = string
  default     = "github-actions-pool"
}

variable "pool_display_name" {
  description = "Workload Identity Pool display name. Defaults to pool_id."
  type        = string
  default     = null
}

variable "pool_description" {
  description = "Workload Identity Pool description."
  type        = string
  default     = "Pool para autenticacao do GitHub Actions"
}

# --- Provider (OIDC) ---

variable "provider_id" {
  description = "Workload Identity Pool Provider id."
  type        = string
  default     = "github-oidc-provider"
}

variable "provider_display_name" {
  description = "Workload Identity Pool Provider display name. Defaults to provider_id."
  type        = string
  default     = null
}

variable "allowed_audiences" {
  description = "Custom audiences for the OIDC provider. Leave empty to use GCP's default audience."
  type        = list(string)
  default     = []
}

variable "attribute_mapping" {
  description = "Attribute mapping from the GitHub OIDC token to Google attributes."
  type        = map(string)
  default = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }
}

variable "attribute_condition" {
  description = "CEL expression restricting which GitHub workflows can authenticate, e.g. \"attribute.repository == 'org/repo'\". Null disables the condition."
  type        = string
  default     = null
}

# --- Service account ---

variable "create_service_account" {
  description = "Whether to create the service account impersonated by GitHub Actions."
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "Account id for the service account created when create_service_account is true."
  type        = string
  default     = "github-deployer"
}

variable "service_account_display_name" {
  description = "Display name for the created service account."
  type        = string
  default     = "GitHub Actions Deployer"
}

variable "existing_service_account_email" {
  description = "Email of an existing service account to use when create_service_account is false."
  type        = string
  default     = null
}

variable "service_account_roles" {
  description = "Project-level IAM roles granted to the service account (principle of least privilege)."
  type        = list(string)
  default     = []
}

# --- GitHub repositories allowed to impersonate the service account ---

variable "github_repositories" {
  description = "GitHub repositories (\"org/repo\") allowed to impersonate the service account via attribute.repository."
  type        = list(string)
  default     = []
}
