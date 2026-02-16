terraform {
  required_version = ">= 1.14.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
