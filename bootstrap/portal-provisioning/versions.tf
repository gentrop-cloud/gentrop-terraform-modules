terraform {
  required_version = ">= 1.5"

  # Aplicado a mao, uma vez, por quem tem Owner no projeto de controle. O bucket
  # ja existe (criado para os roots de clientes/), entao este root guarda o
  # proprio state nele em vez de num laptop.
  backend "gcs" {
    bucket = "gentrop-tfstate"
    prefix = "bootstrap/portal-provisioning"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}
