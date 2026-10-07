variable "project_id" {
  description = "GCP project id where the reasoning engine lives."
  type        = string
}

variable "region" {
  description = "Region for the reasoning engine and staging bucket (e.g. us-central1)."
  type        = string
  default     = "us-central1"
}

variable "display_name" {
  description = "Display name of the reasoning engine."
  type        = string
}

variable "description" {
  description = "Description of the reasoning engine."
  type        = string
  default     = null
}

variable "staging_bucket_name" {
  description = "Globally-unique name for the GCS staging bucket used to hold the agent bundle (pickle/requirements)."
  type        = string
}

variable "package_spec" {
  description = "GCS URIs of the agent bundle built by the app's CI (Vertex AI SDK deploy). Terraform only registers the resource; it doesn't build or upload this bundle."
  type = object({
    pickle_object_gcs_uri    = string
    requirements_gcs_uri     = optional(string)
    dependency_files_gcs_uri = optional(string)
    python_version           = optional(string, "3.11")
  })
}

variable "enable_apis" {
  description = "Enable the Vertex AI and Cloud Storage APIs."
  type        = bool
  default     = true
}

# --- Service account ---

variable "create_service_account" {
  description = "Whether to create a runtime service account for the reasoning engine."
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "Account id for the service account created when create_service_account is true."
  type        = string
  default     = "vertex-agent-engine-runtime"
}

variable "service_account_display_name" {
  description = "Display name for the created service account."
  type        = string
  default     = "Vertex AI Agent Engine runtime service account"
}

variable "existing_service_account_email" {
  description = "Email of an existing service account to use when create_service_account is false."
  type        = string
  default     = null
}

variable "service_account_roles" {
  description = "Project-level IAM roles granted to the runtime service account (e.g. roles/aiplatform.user)."
  type        = list(string)
  default     = []
}

variable "create_reasoning_engine" {
  description = "Create the reasoning engine. Set false until the app CI has uploaded the bundle to the staging bucket, which is created either way."
  type        = bool
  default     = true
}
