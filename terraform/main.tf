# Derived values
locals {
  ssh_private_key_path = trimsuffix(pathexpand(var.ssh_public_key_path), ".pub")

  # Variables passed to Ansible via terraform_vars.yml — always-set values first,
  # then conditionally include optional secrets only when provided.
  ansible_vars = merge(
    {
      region             = var.region
      access_method      = var.access_method
      enable_tailscale   = var.enable_tailscale
      openclaw_version   = var.openclaw_version
      sandbox_mode       = var.sandbox_mode
      llm_providers      = var.llm_providers
      use_prebaked_image = var.custom_image_id != ""
      ssh_allowed_cidrs  = var.ssh_allowed_cidrs
    },
    var.domain_name != "" ? { domain_name = var.domain_name } : {},
    var.claude_setup_token != "" ? { claude_setup_token = var.claude_setup_token } : {},
    var.telegram_bot_token != "" ? { telegram_bot_token = var.telegram_bot_token } : {},
    var.brave_api_key != "" ? { brave_api_key = var.brave_api_key } : {},
    var.enable_backup ? {
      enable_backup            = true
      spaces_access_key_id     = digitalocean_spaces_key.openclaw_backup[0].access_key
      spaces_secret_access_key = digitalocean_spaces_key.openclaw_backup[0].secret_key
      spaces_bucket            = digitalocean_spaces_bucket.openclaw_backup[0].name
    } : {},
  )
}

# SSH Key
resource "digitalocean_ssh_key" "openclaw" {
  name       = "${var.droplet_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Droplet
resource "digitalocean_droplet" "openclaw" {
  name       = var.droplet_name
  region     = var.region
  size       = var.droplet_size
  image      = var.custom_image_id != "" ? var.custom_image_id : "ubuntu-24-04-x64"
  ssh_keys   = [digitalocean_ssh_key.openclaw.fingerprint]
  monitoring = true

  # Create openclaw user at boot so Ansible never needs root SSH
  user_data = <<-EOF
    #!/bin/bash
    useradd -m -s /bin/bash -G sudo openclaw
    echo "openclaw ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw
    chmod 0440 /etc/sudoers.d/openclaw
    mkdir -p /home/openclaw/.ssh
    cp /root/.ssh/authorized_keys /home/openclaw/.ssh/authorized_keys
    chown -R openclaw:openclaw /home/openclaw/.ssh
    chmod 700 /home/openclaw/.ssh
    chmod 600 /home/openclaw/.ssh/authorized_keys
  EOF

  lifecycle {
    precondition {
      condition     = !(var.access_method == "https" && var.openclaw_version == "latest")
      error_message = "openclaw_version must be pinned to a specific version when access_method is 'https' (not 'latest')"
    }
  }

  tags = ["openclaw"]
}

# Firewall
resource "digitalocean_firewall" "openclaw" {
  name        = "${var.droplet_name}-fw"
  droplet_ids = [digitalocean_droplet.openclaw.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = length(var.ssh_allowed_cidrs) > 0 ? var.ssh_allowed_cidrs : ["0.0.0.0/0", "::/0"]
  }

  # OpenClaw Gateway — only open publicly if https access
  dynamic "inbound_rule" {
    for_each = var.access_method == "https" ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "443"
      source_addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  # HTTP for Let's Encrypt ACME challenge
  dynamic "inbound_rule" {
    for_each = var.access_method == "https" ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "80"
      source_addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  # All outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Project
resource "digitalocean_project" "openclaw" {
  name        = var.project_name
  description = "OpenClaw AI Assistant"
  purpose     = "Service or API"
  environment = "Production"
  resources   = [digitalocean_droplet.openclaw.urn]
}

# Backup bucket (DO Spaces)
resource "digitalocean_spaces_bucket" "openclaw_backup" {
  count  = var.enable_backup ? 1 : 0
  name   = "${var.droplet_name}-backups"
  region = var.region

  lifecycle {
    prevent_destroy = true
  }
}

# Spaces access key for backup
resource "digitalocean_spaces_key" "openclaw_backup" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.droplet_name}-backup-key"

  grant {
    bucket     = digitalocean_spaces_bucket.openclaw_backup[0].name
    permission = "readwrite"
  }
}

# Optional DNS
resource "digitalocean_domain" "openclaw" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

resource "digitalocean_record" "openclaw_a" {
  count  = var.domain_name != "" ? 1 : 0
  domain = digitalocean_domain.openclaw[0].id
  type   = "A"
  name   = "@"
  value  = digitalocean_droplet.openclaw.ipv4_address
  ttl    = 300
}

# Generated Ansible files
resource "local_sensitive_file" "ansible_vars" {
  filename        = "${path.module}/../ansible/terraform_vars.yml"
  file_permission = "0600"
  content         = "---\n# Auto-generated by Terraform — do not edit\n${yamlencode(local.ansible_vars)}"
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content = join("\n", [
    "[openclaw]",
    "openclaw-server ansible_host=${digitalocean_droplet.openclaw.ipv4_address} ansible_user=openclaw ansible_become=true ansible_ssh_private_key_file=${local.ssh_private_key_path}",
    "",
  ])
}
