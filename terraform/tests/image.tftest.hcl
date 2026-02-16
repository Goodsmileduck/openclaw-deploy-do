# terraform/tests/image.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "default_image_is_ubuntu" {
  command = plan

  assert {
    condition     = digitalocean_droplet.openclaw.image == "ubuntu-24-04-x64"
    error_message = "Default image should be ubuntu-24-04-x64 when custom_image_id is empty"
  }
}

run "custom_image_overrides_default" {
  command = plan

  variables {
    custom_image_id = "123456789"
  }

  assert {
    condition     = digitalocean_droplet.openclaw.image == "123456789"
    error_message = "Droplet should use custom_image_id when provided"
  }
}

run "use_prebaked_image_false_by_default" {
  command = plan

  assert {
    condition     = local.ansible_vars.use_prebaked_image == false
    error_message = "use_prebaked_image should be false when custom_image_id is empty"
  }
}

run "use_prebaked_image_true_when_custom_image" {
  command = plan

  variables {
    custom_image_id = "123456789"
  }

  assert {
    condition     = local.ansible_vars.use_prebaked_image == true
    error_message = "use_prebaked_image should be true when custom_image_id is set"
  }
}
