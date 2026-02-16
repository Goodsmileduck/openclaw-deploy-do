packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.4.0"
      source  = "github.com/digitalocean/digitalocean"
    }
  }
}

variable "do_token" {
  type      = string
  sensitive = true
}

variable "region" {
  type    = string
  default = "nyc3"
}

variable "snapshot_name" {
  type    = string
  default = ""
}

locals {
  snapshot_name = var.snapshot_name != "" ? var.snapshot_name : "openclaw-base-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
}

source "digitalocean" "openclaw-base" {
  api_token     = var.do_token
  image         = "ubuntu-24-04-x64"
  region        = var.region
  size          = "s-1vcpu-1gb"
  ssh_username  = "root"
  snapshot_name = local.snapshot_name
  snapshot_regions = [var.region]
}

build {
  sources = ["source.digitalocean.openclaw-base"]

  provisioner "shell" {
    script = "scripts/base-setup.sh"
  }

  provisioner "shell" {
    script = "scripts/docker-setup.sh"
  }

  provisioner "shell" {
    script = "scripts/nodejs-setup.sh"
  }

  provisioner "shell" {
    script = "scripts/extras-setup.sh"
  }

  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }
}
