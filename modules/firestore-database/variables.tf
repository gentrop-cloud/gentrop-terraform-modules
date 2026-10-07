variable "project_id" {
  description = "GCP project id where the database lives."
  type        = string
}

variable "database_id" {
  description = "Firestore database id. Use \"(default)\" for the project's default database."
  type        = string
  default     = "(default)"
}

variable "location_id" {
  description = "Region or multi-region (e.g. nam5) for the Firestore database."
  type        = string
  default     = "us-central1"
}

variable "delete_protection_state" {
  description = "DELETE_PROTECTION_ENABLED blocks deletion via API/Terraform; DELETE_PROTECTION_DISABLED allows it."
  type        = string
  default     = "DELETE_PROTECTION_ENABLED"
}

variable "point_in_time_recovery_enablement" {
  description = "POINT_IN_TIME_RECOVERY_ENABLED keeps 7 days of PITR; POINT_IN_TIME_RECOVERY_DISABLED turns it off."
  type        = string
  default     = "POINT_IN_TIME_RECOVERY_DISABLED"
}

variable "enable_apis" {
  description = "Enable the Firestore API."
  type        = bool
  default     = true
}
