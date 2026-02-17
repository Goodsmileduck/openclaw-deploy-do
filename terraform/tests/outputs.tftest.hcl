# terraform/tests/outputs.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "output_gateway_url_ssh_tunnel" {
  command = plan

  variables {
    access_method = "ssh_tunnel"
  }

  assert {
    condition     = startswith(output.gateway_url, "http://localhost:18789")
    error_message = "SSH tunnel gateway_url should start with http://localhost:18789"
  }
}

run "output_gateway_url_https" {
  command = plan

  variables {
    access_method    = "https"
    domain_name      = "openclaw.example.com"
    openclaw_version = "1.0.0"
  }

  assert {
    condition     = output.gateway_url == "https://openclaw.example.com"
    error_message = "HTTPS gateway_url should be https://<domain_name>"
  }
}

run "output_access_method_matches_input" {
  command = plan

  variables {
    access_method    = "https"
    openclaw_version = "1.0.0"
  }

  assert {
    condition     = output.access_method == "https"
    error_message = "access_method output should match input variable"
  }
}

run "output_llm_providers_passthrough" {
  command = plan

  variables {
    access_method = "ssh_tunnel"
    llm_providers = [
      { name = "openai" },
      { name = "anthropic" },
    ]
  }

  assert {
    condition     = output.llm_providers == ["openai", "anthropic"]
    error_message = "llm_providers output should list provider names"
  }
}
