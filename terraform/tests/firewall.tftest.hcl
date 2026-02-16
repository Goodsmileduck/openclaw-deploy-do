# terraform/tests/firewall.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "firewall_https_opens_web_ports" {
  command = plan

  variables {
    access_method = "https"
  }

  assert {
    condition     = length(digitalocean_firewall.openclaw.inbound_rule) == 3
    error_message = "HTTPS mode should have 3 inbound rules (SSH + HTTPS + HTTP)"
  }
}

run "firewall_ssh_tunnel_no_web_ports" {
  command = plan

  variables {
    access_method = "ssh_tunnel"
  }

  assert {
    condition     = length(digitalocean_firewall.openclaw.inbound_rule) == 1
    error_message = "SSH tunnel mode should have only 1 inbound rule (SSH only)"
  }
}

run "firewall_always_has_outbound" {
  command = plan

  variables {
    access_method = "ssh_tunnel"
  }

  assert {
    condition     = length(digitalocean_firewall.openclaw.outbound_rule) == 3
    error_message = "Should always have 3 outbound rules (TCP + UDP + ICMP)"
  }
}
