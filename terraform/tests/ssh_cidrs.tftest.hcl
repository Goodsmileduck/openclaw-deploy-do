# terraform/tests/ssh_cidrs.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "ssh_default_open_to_all" {
  command = plan

  variables {
    ssh_allowed_cidrs = []
  }

  assert {
    condition = anytrue([
      for rule in digitalocean_firewall.openclaw.inbound_rule :
      rule.port_range == "22" && contains(rule.source_addresses, "0.0.0.0/0")
    ])
    error_message = "Empty ssh_allowed_cidrs should open SSH to all"
  }
}

run "ssh_restricted_to_single_cidr" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["203.0.113.0/24"]
  }

  assert {
    condition = anytrue([
      for rule in digitalocean_firewall.openclaw.inbound_rule :
      rule.port_range == "22" && contains(rule.source_addresses, "203.0.113.0/24") && !contains(rule.source_addresses, "0.0.0.0/0")
    ])
    error_message = "SSH should be restricted to specified CIDR"
  }
}

run "ssh_restricted_to_multiple_cidrs" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
  }

  assert {
    condition = anytrue([
      for rule in digitalocean_firewall.openclaw.inbound_rule :
      rule.port_range == "22" && contains(rule.source_addresses, "203.0.113.0/24") && contains(rule.source_addresses, "198.51.100.0/24")
    ])
    error_message = "SSH should be restricted to all specified CIDRs"
  }
}

run "ssh_rejects_invalid_cidr" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["not-a-cidr"]
  }

  expect_failures = [
    var.ssh_allowed_cidrs,
  ]
}
