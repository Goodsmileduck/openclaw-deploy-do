# terraform/tests/setup.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "plan_succeeds_with_basic_config" {
  command = plan

  variables {
    region       = "nyc3"
    droplet_size = "s-2vcpu-4gb"
    droplet_name = "openclaw-server"
  }

  assert {
    condition     = digitalocean_droplet.openclaw.name == "openclaw-server"
    error_message = "Droplet name should match droplet_name variable"
  }

  assert {
    condition     = digitalocean_droplet.openclaw.region == "nyc3"
    error_message = "Droplet region should match region variable"
  }

  assert {
    condition     = digitalocean_droplet.openclaw.size == "s-2vcpu-4gb"
    error_message = "Droplet size should match droplet_size variable"
  }

  assert {
    condition     = digitalocean_droplet.openclaw.image == "ubuntu-24-04-x64"
    error_message = "Image should be ubuntu-24-04-x64"
  }
}
