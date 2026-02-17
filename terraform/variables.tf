variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_do_ssh.pub"
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
  description = "Remote access method: ssh_tunnel or https"
  type        = string
  default     = "ssh_tunnel"

  validation {
    condition     = contains(["ssh_tunnel", "https"], var.access_method)
    error_message = "access_method must be one of: ssh_tunnel, https"
  }
}

variable "enable_tailscale" {
  description = "Enable Tailscale mesh VPN (works alongside any access_method)"
  type        = bool
  default     = false
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

variable "claude_setup_token" {
  description = "Claude setup token (from: claude setup-token)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token from @BotFather"
  type        = string
  default     = ""
  sensitive   = true
}

variable "brave_api_key" {
  description = "Brave Search API key for web_search tool"
  type        = string
  default     = ""
  sensitive   = true
}

variable "openclaw_version" {
  description = "OpenClaw npm package version"
  type        = string
  default     = "latest"
}

variable "sandbox_mode" {
  description = "Agent sandbox mode: off, non-main, or all"
  type        = string
  default     = "non-main"

  validation {
    condition     = contains(["off", "non-main", "all"], var.sandbox_mode)
    error_message = "sandbox_mode must be one of: off, non-main, all"
  }
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH into the droplet (empty list = open to all)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.ssh_allowed_cidrs :
      can(cidrhost(cidr, 0))
    ])
    error_message = "Each entry in ssh_allowed_cidrs must be a valid CIDR (e.g. 203.0.113.0/24, ::/0)"
  }
}

variable "custom_image_id" {
  description = "Pre-baked DigitalOcean snapshot ID. Leave empty for vanilla Ubuntu 24.04."
  type        = string
  default     = ""
}

variable "enable_backup" {
  description = "Enable restic backup to DigitalOcean Spaces"
  type        = bool
  default     = false
}

variable "spaces_access_key_id" {
  description = "DigitalOcean Spaces access key (required when enable_backup is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "spaces_secret_access_key" {
  description = "DigitalOcean Spaces secret key (required when enable_backup is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "llm_providers" {
  description = "LLM providers — first entry becomes the primary model"
  type = list(object({
    name    = string
    api_key = optional(string, "")
    model   = optional(string, "")
  }))
  default = []

  validation {
    condition = alltrue([
      for p in var.llm_providers :
      contains(["anthropic", "openai", "openrouter", "gemini", "do_ai", "gradient", "custom"], p.name)
    ])
    error_message = "Each provider name must be one of: anthropic, openai, openrouter, gemini, do_ai, gradient, custom"
  }
}
