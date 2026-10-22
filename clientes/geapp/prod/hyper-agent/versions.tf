terraform {
  required_version = ">= 1.5"

  # State remoto isolado por cliente/ambiente: o prefix e o que impede um
  # apply aqui de enxergar (e destruir) recursos de outro cliente/stack.
  backend "gcs" {
    bucket = "gentrop-tfstate"                 # mesmo bucket de clientes/geapp/prod/app; prefix abaixo e proprio
    prefix = "clientes/geapp-prod-hyper-agent" # nome antigo da pasta; manter evita migrate-state
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}
