terraform {
  required_version = ">= 1.5"

  # Aplicado a mao, uma vez, por quem tem Owner no geapp-dev-seed-0001. O state do
  # proprio bootstrap fica no gentrop-tfstate (ja existe); o bucket de state dos
  # clientes de dev e criado por este root.
  backend "gcs" {
    bucket = "gentrop-tfstate"
    prefix = "bootstrap/geapp-manager-dev"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}
