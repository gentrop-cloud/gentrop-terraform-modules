variable "project_id" {
  description = "GCP project id where the job lives."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Scheduler job."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Cloud Scheduler job name."
  type        = string
}

variable "description" {
  description = "Job description."
  type        = string
  default     = null
}

variable "schedule" {
  description = "Cron schedule (e.g. \"0 10 * * *\" for 10h00)."
  type        = string
}

variable "time_zone" {
  description = "Time zone for the schedule (e.g. America/Sao_Paulo)."
  type        = string
  default     = "America/Sao_Paulo"
}

variable "uri" {
  description = "Target HTTP(S) URL, e.g. the Cloud Run service URL."
  type        = string
}

variable "http_method" {
  description = "HTTP method used for the request."
  type        = string
  default     = "POST"
}

variable "body" {
  description = "Request body (plain text/JSON string). Null for no body."
  type        = string
  default     = null
}

variable "headers" {
  description = "HTTP headers sent with the request."
  type        = map(string)
  default     = {}
}

variable "enable_apis" {
  description = "Enable the Cloud Scheduler API."
  type        = bool
  default     = true
}

# --- Service account (used for the OIDC token that authenticates the request) ---

variable "create_service_account" {
  description = "Whether to create a service account for this job."
  type        = bool
  default     = true
}

variable "service_account_id" {
  description = "Account id for the service account created when create_service_account is true."
  type        = string
  default     = "cloud-scheduler-invoker"
}

variable "service_account_display_name" {
  description = "Display name for the created service account."
  type        = string
  default     = "Cloud Scheduler invoker service account"
}

variable "existing_service_account_email" {
  description = "Email of an existing service account to use when create_service_account is false."
  type        = string
  default     = null
}
