variable "project_id" {
  description = "GCP project id where the repository lives."
  type        = string
}

variable "location" {
  description = "Region for the Artifact Registry repository."
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Repository id."
  type        = string
  default     = "cloud-run-source-deploy"
}

variable "description" {
  description = "Repository description."
  type        = string
  default     = "Imagens de container para deploy no Cloud Run"
}

variable "format" {
  description = "Repository format (DOCKER, NPM, MAVEN, ...)."
  type        = string
  default     = "DOCKER"
}

variable "enable_apis" {
  description = "Enable the Artifact Registry API."
  type        = bool
  default     = true
}
