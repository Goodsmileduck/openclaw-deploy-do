# terraform/tests/variables.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

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

# llm_providers validation

run "llm_providers_accepts_single_provider" {
  command = plan

  variables {
    llm_providers = [{ name = "anthropic" }]
  }

  assert {
    condition     = length(var.llm_providers) == 1
    error_message = "Single provider should be accepted"
  }
}

run "llm_providers_accepts_multiple_providers" {
  command = plan

  variables {
    llm_providers = [
      { name = "anthropic", api_key = "sk-test" },
      { name = "openai", api_key = "sk-test2" },
    ]
  }

  assert {
    condition     = length(var.llm_providers) == 2
    error_message = "Multiple providers should be accepted"
  }
}

run "llm_providers_accepts_empty_list" {
  command = plan

  variables {
    llm_providers = []
  }

  assert {
    condition     = length(var.llm_providers) == 0
    error_message = "Empty list should be accepted"
  }
}

run "llm_providers_rejects_invalid_name" {
  command = plan

  variables {
    llm_providers = [{ name = "invalid_provider" }]
  }

  expect_failures = [
    var.llm_providers,
  ]
}

run "llm_providers_accepts_with_model_override" {
  command = plan

  variables {
    llm_providers = [{ name = "anthropic", model = "anthropic/claude-sonnet-4-5" }]
  }

  assert {
    condition     = var.llm_providers[0].model == "anthropic/claude-sonnet-4-5"
    error_message = "Model override should be preserved"
  }
}

# sandbox_mode validation

run "sandbox_mode_accepts_non_main" {
  command = plan

  variables {
    sandbox_mode = "non-main"
  }

  assert {
    condition     = var.sandbox_mode == "non-main"
    error_message = "non-main should be accepted"
  }
}

run "sandbox_mode_rejects_invalid" {
  command = plan

  variables {
    sandbox_mode = "invalid_mode"
  }

  expect_failures = [
    var.sandbox_mode,
  ]
}
