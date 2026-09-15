variable "project_id" {
  description = "GCP project id where the dataset lives."
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset id."
  type        = string
}

variable "location" {
  description = "Location for the dataset (e.g. US, us-central1)."
  type        = string
  default     = "US"
}

variable "tables" {
  description = "Tables to create: key = table_id, value = { schema = <JSON string>, deletion_protection = bool }."
  type = map(object({
    schema              = string
    deletion_protection = optional(bool, false)
  }))
  default = {}
}

variable "enable_apis" {
  description = "Enable the BigQuery API."
  type        = bool
  default     = true
}
