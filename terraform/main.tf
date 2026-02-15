# SSH Key
resource "digitalocean_ssh_key" "openclaw" {
  name       = "${var.droplet_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Droplet
resource "digitalocean_droplet" "openclaw" {
  name     = var.droplet_name
  region   = var.region
  size     = var.droplet_size
  image    = "ubuntu-24-04-x64"
  ssh_keys = [digitalocean_ssh_key.openclaw.fingerprint]

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
    source_addresses = ["0.0.0.0/0", "::/0"]
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
