terraform {
  required_version = ">= 1.5"

  # Aplicado a mao por quem tem Owner no geapp-dev-seed-0001, como o bootstrap.
  backend "gcs" {
    bucket = "gentrop-tfstate"
    prefix = "bootstrap/geapp-manager-dev-hosting"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
