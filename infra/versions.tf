terraform {
  required_version = ">= 1.8.0"

  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.31.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

