terraform {
  required_version = ">= 1.5"

  # Config parcial: bucket e prefix vem do `terraform init -backend-config` no
  # provision.yml, como clientes/<client_slug>/<stack>. Um state por cliente.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}
