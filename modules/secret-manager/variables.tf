variable "project_id" {
  description = "GCP project id where the secrets live."
  type        = string
}

variable "secret_ids" {
  description = "Secret ids to create (containers only, no version). Values are populated later, manually or via CD."
  type        = list(string)
}

variable "enable_apis" {
  description = "Enable the Secret Manager API."
  type        = bool
  default     = true
}
