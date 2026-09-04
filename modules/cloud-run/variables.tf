variable "project_id" {
  description = "GCP project id where the service lives."
  type        = string
}

variable "location" {
  description = "Region for the Cloud Run service."
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
}

variable "image" {
  description = "Initial container image. The CD pipeline deploys new images afterwards (Terraform ignores changes to this field to avoid fighting the CD)."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "cpu" {
  description = "CPU limit per container instance."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit per container instance."
  type        = string
  default     = "512Mi"
}

variable "env_vars" {
  description = "Plain (non-secret) environment variables, e.g. { GOOGLE_CLIENT_ID = \"...\" }."
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Environment variables sourced from Secret Manager: key = env var name, value = secret id (always reads the \"latest\" version)."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Prevents the service from being destroyed by Terraform. Keep false for dev/test; set true once the service is stable in production."
  type        = bool
  default     = false
}

variable "allow_unauthenticated" {
  description = "Whether to allow public (unauthenticated) invocations."
  type        = bool
  default     = true
}

variable "enable_apis" {
  description = "Enable the Cloud Run API."
  type        = bool
  default     = true
}

# --- Service account ---

variable "create_service_account" {
  description = "Whether to create a runtime service account for the service."
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "Account id for the service account created when create_service_account is true."
  type        = string
  default     = "cloud-run-runtime"
}

variable "service_account_display_name" {
  description = "Display name for the created service account."
  type        = string
  default     = "Cloud Run runtime service account"
}

variable "existing_service_account_email" {
  description = "Email of an existing service account to use when create_service_account is false."
  type        = string
  default     = null
}

variable "service_account_roles" {
  description = "Project-level IAM roles granted to the runtime service account (e.g. roles/secretmanager.secretAccessor, roles/cloudsql.client)."
  type        = list(string)
  default     = []
}

variable "cloudsql_connection_name" {
  description = "Cloud SQL instance connection name (PROJECT:REGION:INSTANCE) to mount via the Cloud SQL Auth Proxy at /cloudsql. Null skips it entirely."
  type        = string
  default     = null
}
