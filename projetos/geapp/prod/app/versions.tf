terraform {
  required_version = ">= 1.5"

  # State remoto isolado por projeto/ambiente: o prefix e o que impede um
  # apply aqui de enxergar (e destruir) recursos de outro projeto.
  backend "gcs" {
    bucket = "gentrop-tfstate"     # TROQUE: bucket criado conforme o README desta pasta
    prefix = "clientes/geapp-prod" # nome antigo da pasta; manter evita migrate-state
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}
