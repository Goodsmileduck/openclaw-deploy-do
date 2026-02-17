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

output "ssh_command" {
  description = "SSH command to access the Droplet"
  value       = "ssh openclaw@${digitalocean_droplet.openclaw.ipv4_address}"
}

output "ssh_private_key_path" {
  description = "SSH private key path (derived from public key path)"
  value       = local.ssh_private_key_path
}

output "backup_bucket" {
  description = "DO Spaces backup bucket domain (null when backup is disabled)"
  value       = var.enable_backup ? digitalocean_spaces_bucket.openclaw_backup[0].bucket_domain_name : null
}

output "llm_providers" {
  description = "Configured LLM providers"
  value       = [for p in var.llm_providers : p.name]
}
