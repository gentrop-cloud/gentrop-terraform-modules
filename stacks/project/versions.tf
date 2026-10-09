terraform {
  required_version = ">= 1.5"

  # Config parcial: bucket e prefix vem do `terraform init -backend-config` no
  # provision.yml, como clientes/<client_slug>/project.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0" # deletion_policy no google_project
    }
  }
}
