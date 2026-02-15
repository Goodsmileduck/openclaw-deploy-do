# terraform/tests/variables.tftest.hcl
mock_provider "digitalocean" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "access_method_accepts_ssh_tunnel" {
  command = plan

  variables {
    access_method = "ssh_tunnel"
  }

  assert {
    condition     = var.access_method == "ssh_tunnel"
    error_message = "ssh_tunnel should be accepted"
  }
}

run "access_method_accepts_https" {
  command = plan

  variables {
    access_method = "https"
  }

  assert {
    condition     = var.access_method == "https"
    error_message = "https should be accepted"
  }
}

run "access_method_rejects_invalid" {
  command = plan

  variables {
    access_method = "invalid_method"
  }

  expect_failures = [
    var.access_method,
  ]
}

run "access_method_rejects_empty" {
  command = plan

  variables {
    access_method = ""
  }

  expect_failures = [
    var.access_method,
  ]
}
