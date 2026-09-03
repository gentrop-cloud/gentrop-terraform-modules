terraform {
  required_version = ">= 1.3.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.21.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}