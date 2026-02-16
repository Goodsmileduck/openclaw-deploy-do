# terraform/tests/dns.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "dns_created_when_domain_set" {
  command = plan

  variables {
    domain_name = "example.com"
  }

  assert {
    condition     = length(digitalocean_domain.openclaw) == 1
    error_message = "Domain resource should be created when domain_name is set"
  }

  assert {
    condition     = length(digitalocean_record.openclaw_a) == 1
    error_message = "A record should be created when domain_name is set"
  }
}

run "dns_skipped_when_domain_empty" {
  command = plan

  variables {
    domain_name = ""
  }

  assert {
    condition     = length(digitalocean_domain.openclaw) == 0
    error_message = "Domain resource should not be created when domain_name is empty"
  }

  assert {
    condition     = length(digitalocean_record.openclaw_a) == 0
    error_message = "A record should not be created when domain_name is empty"
  }
}
