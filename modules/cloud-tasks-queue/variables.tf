variable "project_id" {
  description = "GCP project id where the queue lives."
  type        = string
}

variable "location" {
  description = "Region for the Cloud Tasks queue."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Cloud Tasks queue name."
  type        = string
}

variable "max_dispatches_per_second" {
  description = "Max dispatches per second, used to throttle calls to the target (e.g. to avoid LLM quota/timeout issues)."
  type        = number
  default     = 1
}

variable "max_concurrent_dispatches" {
  description = "Max number of tasks dispatched concurrently."
  type        = number
  default     = 1
}

variable "max_attempts" {
  description = "Max retry attempts per task."
  type        = number
  default     = 5
}

variable "enqueuer_members" {
  description = "IAM members (e.g. \"serviceAccount:x@y.iam.gserviceaccount.com\") granted roles/cloudtasks.enqueuer on this queue."
  type        = list(string)
  default     = []
}

variable "enable_apis" {
  description = "Enable the Cloud Tasks API."
  type        = bool
  default     = true
}
