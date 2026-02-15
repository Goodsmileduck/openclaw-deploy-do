variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Droplet size slug (minimum s-2vcpu-4gb recommended)"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "droplet_name" {
  description = "Name for the Droplet"
  type        = string
  default     = "openclaw-server"
}

variable "access_method" {
  description = "Remote access method: ssh_tunnel, tailscale, or https"
  type        = string
  default     = "ssh_tunnel"

  validation {
    condition     = contains(["ssh_tunnel", "tailscale", "https"], var.access_method)
    error_message = "access_method must be one of: ssh_tunnel, tailscale, https"
  }
}

variable "domain_name" {
  description = "Domain name for HTTPS access (required when access_method is https)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "DigitalOcean project name"
  type        = string
  default     = "OpenClaw"
}
