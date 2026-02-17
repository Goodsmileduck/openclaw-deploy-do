# terraform/tests/version.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "version_latest_allowed_with_ssh_tunnel" {
  command = plan

  variables {
    access_method    = "ssh_tunnel"
    openclaw_version = "latest"
  }

  assert {
    condition     = var.openclaw_version == "latest"
    error_message = "latest should be accepted with ssh_tunnel"
  }
}

run "version_pinned_allowed_with_https" {
  command = plan

  variables {
    access_method    = "https"
    domain_name      = "test.example.com"
    openclaw_version = "1.2.3"
  }

  assert {
    condition     = var.openclaw_version == "1.2.3"
    error_message = "Pinned version should be accepted with https"
  }
}

run "version_latest_rejected_with_https" {
  command = plan

  variables {
    access_method    = "https"
    domain_name      = "test.example.com"
    openclaw_version = "latest"
  }

  expect_failures = [
    digitalocean_droplet.openclaw,
  ]
}

run "version_pinned_allowed_with_ssh_tunnel" {
  command = plan

  variables {
    access_method    = "ssh_tunnel"
    openclaw_version = "2.0.0"
  }

  assert {
    condition     = var.openclaw_version == "2.0.0"
    error_message = "Pinned version should be accepted with ssh_tunnel"
  }
}
