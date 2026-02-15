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
    ) : var.access_method == "ssh_tunnel" ? (
    "http://localhost:18789 (via SSH tunnel: ssh -L 18789:localhost:18789 openclaw@${digitalocean_droplet.openclaw.ipv4_address})"
    ) : (
    "Available on your Tailscale network after setup"
  )
}

output "ssh_command" {
  description = "SSH command to access the Droplet"
  value       = "ssh openclaw@${digitalocean_droplet.openclaw.ipv4_address}"
}
