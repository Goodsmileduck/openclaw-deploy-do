output "droplet_ip" {
  description = "Public IPv4 address of the OpenClaw Droplet"
  value       = digitalocean_droplet.openclaw.ipv4_address
}

output "droplet_id" {
  description = "Droplet ID"
  value       = digitalocean_droplet.openclaw.id
}

output "access_method" {
  description = "Configured access method"
  value       = var.access_method
}

output "gateway_url" {
  description = "OpenClaw Gateway URL (based on access method)"
  value = var.access_method == "https" && var.domain_name != "" ? (
    "https://${var.domain_name}"
    ) : (
    "http://localhost:18789 (via SSH tunnel: ssh -L 18789:localhost:18789 openclaw@${digitalocean_droplet.openclaw.ipv4_address})"
  )
}

output "region" {
  description = "DigitalOcean region (passed through to Ansible)"
  value       = var.region
}

output "enable_tailscale" {
  description = "Whether Tailscale is enabled"
  value       = var.enable_tailscale
}

output "ssh_command" {
  description = "SSH command to access the Droplet"
  value       = "ssh openclaw@${digitalocean_droplet.openclaw.ipv4_address}"
}

output "ssh_public_key_path" {
  description = "SSH public key path (used by deploy.sh to derive private key)"
  value       = var.ssh_public_key_path
}

output "claude_setup_token" {
  description = "Claude setup token (passed through to Ansible)"
  value       = var.claude_setup_token
  sensitive   = true
}

output "telegram_bot_token" {
  description = "Telegram bot token (passed through to Ansible)"
  value       = var.telegram_bot_token
  sensitive   = true
}
