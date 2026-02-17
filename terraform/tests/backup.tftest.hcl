# terraform/tests/backup.tftest.hcl
mock_provider "digitalocean" {}
mock_provider "local" {}

variables {
  do_token            = "mock-token-for-testing"
  ssh_public_key_path = "~/.ssh/id_do_ssh.pub"
}

run "backup_disabled_by_default" {
  command = plan

  assert {
    condition     = length(digitalocean_spaces_bucket.openclaw_backup) == 0
    error_message = "Spaces bucket should not be created when enable_backup is false"
  }

  assert {
    condition     = length(digitalocean_spaces_key.openclaw_backup) == 0
    error_message = "Spaces key should not be created when enable_backup is false"
  }
}

run "backup_creates_bucket_and_key" {
  command = plan

  variables {
    enable_backup = true
  }

  assert {
    condition     = length(digitalocean_spaces_bucket.openclaw_backup) == 1
    error_message = "Spaces bucket should be created when enable_backup is true"
  }

  assert {
    condition     = length(digitalocean_spaces_key.openclaw_backup) == 1
    error_message = "Spaces key should be created when enable_backup is true"
  }
}

run "backup_names_derive_from_droplet_name" {
  command = plan

  variables {
    enable_backup = true
    droplet_name  = "my-server"
  }

  assert {
    condition     = digitalocean_spaces_bucket.openclaw_backup[0].name == "my-server-backups"
    error_message = "Spaces bucket name should be <droplet_name>-backups"
  }

  assert {
    condition     = digitalocean_spaces_key.openclaw_backup[0].name == "my-server-backup-key"
    error_message = "Spaces key name should be <droplet_name>-backup-key"
  }
}

run "backup_bucket_uses_droplet_region" {
  command = plan

  variables {
    enable_backup = true
    region        = "sgp1"
  }

  assert {
    condition     = digitalocean_spaces_bucket.openclaw_backup[0].region == "sgp1"
    error_message = "Spaces bucket region should match the region variable"
  }
}

run "backup_injects_vars_into_ansible" {
  command = plan

  variables {
    enable_backup = true
  }

  assert {
    condition     = nonsensitive(tostring(local.ansible_vars.enable_backup)) == "true"
    error_message = "ansible_vars should include enable_backup = true when backup is enabled"
  }

  assert {
    condition     = nonsensitive(local.ansible_vars.spaces_bucket) == "openclaw-server-backups"
    error_message = "ansible_vars should include spaces_bucket set to <droplet_name>-backups"
  }
}

run "backup_disabled_omits_ansible_vars" {
  command = plan

  assert {
    condition     = !contains(keys(local.ansible_vars), "enable_backup")
    error_message = "ansible_vars should not include enable_backup when backup is disabled"
  }

  assert {
    condition     = !contains(keys(local.ansible_vars), "spaces_bucket")
    error_message = "ansible_vars should not include spaces_bucket when backup is disabled"
  }
}
