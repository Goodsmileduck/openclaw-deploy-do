# OpenClaw DigitalOcean IaC

Infrastructure as Code for deploying [OpenClaw](https://docs.openclaw.ai/) to a DigitalOcean Droplet. Uses Terraform to provision infrastructure (Droplet, firewall, SSH key, optional DNS) and Ansible to configure the server with Docker, Node.js, OpenClaw, and your choice of access method (SSH tunnel, Tailscale, or HTTPS with Let's Encrypt).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.14.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) >= 2.15
- A [DigitalOcean](https://www.digitalocean.com/) account and API token
- An SSH key pair (configurable via `ssh_public_key_path`)
- An LLM API key or Claude subscription (see [LLM Authentication](#llm-authentication))

## Quick Start

### 1. Configure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your DO token, SSH key path, and region
```

### 2. Deploy

```bash
# With an API key
./scripts/deploy.sh --extra-vars "llm_api_key=your-api-key-here"

# Or without — configure auth on the server after deploy
./scripts/deploy.sh
```

### 3. Connect

**SSH Tunnel (default):**
```bash
ssh -L 18789:localhost:18789 openclaw@<droplet-ip>
# Then open http://localhost:18789
```

**Tailscale:** Available on your Tailscale network after setup.

**HTTPS:** Open `https://your-domain.com` directly.

## LLM Authentication

OpenClaw supports multiple LLM providers and auth methods. See the [model providers docs](https://docs.openclaw.ai/concepts/model-providers) for full details.

### Option A: API Key (at deploy time)

Pass your key via `--extra-vars`:

```bash
# Anthropic (default)
./scripts/deploy.sh --extra-vars "llm_api_key=sk-ant-..."

# OpenAI
./scripts/deploy.sh --extra-vars "llm_provider=openai llm_api_key=sk-..."

# OpenRouter (access Claude, GPT, and other models via proxy)
./scripts/deploy.sh --extra-vars "llm_provider=openrouter llm_api_key=sk-or-..."

# Google Gemini
./scripts/deploy.sh --extra-vars "llm_provider=gemini llm_api_key=..."
```

### Option B: Claude Setup Token (post-deploy)

If you have a Claude Pro or Max subscription, you can use `setup-token` instead of an API key. Deploy without a key, then SSH in:

```bash
ssh openclaw@<droplet-ip>
claude setup-token
openclaw models auth setup-token --provider anthropic
```

See the [authentication docs](https://docs.openclaw.ai/gateway/authentication) for more details.

## Configuration Reference

### Terraform Variables (`terraform/terraform.tfvars`)

| Variable | Description | Default |
|---|---|---|
| `do_token` | DigitalOcean API token | (required) |
| `ssh_public_key_path` | Path to SSH public key | `~/.ssh/id_rsa.pub` |
| `region` | DigitalOcean region | `nyc3` |
| `droplet_size` | Droplet size slug | `s-2vcpu-4gb` |
| `droplet_name` | Name for the Droplet | `openclaw-server` |
| `access_method` | Access method: `ssh_tunnel`, `tailscale`, `https` | `ssh_tunnel` |
| `domain_name` | Domain for HTTPS (required if `access_method=https`) | `""` |
| `project_name` | DigitalOcean project name | `OpenClaw` |

### Ansible Variables (`ansible/group_vars/all.yml`)

| Variable | Description | Default |
|---|---|---|
| `llm_provider` | `anthropic`, `openai`, `openrouter`, `gemini`, `gradient`, `custom` | `anthropic` |
| `llm_api_key` | API key (optional — can use setup-token instead) | `""` |
| `llm_model` | Model override (leave empty for provider default) | `""` |
| `access_method` | Must match Terraform setting | `ssh_tunnel` |
| `openclaw_gateway_token` | Gateway auth token (auto-generated if empty) | `""` |
| `domain_name` | Domain for HTTPS access | `""` |
| `certbot_email` | Email for Let's Encrypt | `""` |
| `tailscale_auth_key` | Tailscale pre-auth key | `""` |

## Access Methods

### SSH Tunnel (default)

The most secure option. No ports are exposed beyond SSH. Connect via:

```bash
ssh -L 18789:localhost:18789 openclaw@<droplet-ip>
```

### Tailscale

Uses Tailscale mesh VPN. The gateway is exposed only to your Tailscale network. Requires a Tailscale account and pre-auth key.

```bash
# In terraform.tfvars
access_method = "tailscale"

# Deploy with Tailscale auth key
./scripts/deploy.sh --extra-vars "tailscale_auth_key=tskey-auth-..."
```

### HTTPS

Publicly accessible with TLS via Let's Encrypt. Requires a domain name pointed at DigitalOcean nameservers (or managed via DO DNS).

```bash
# In terraform.tfvars
access_method = "https"
domain_name   = "openclaw.example.com"

# Deploy with certbot email
./scripts/deploy.sh --extra-vars "certbot_email=you@example.com"
```

## Post-Deploy

### Add Channels

```bash
ssh openclaw@<droplet-ip>
openclaw channels add
```

### Install Skills

```bash
ssh openclaw@<droplet-ip>
openclaw skills install <skill-name>
```

For more on channels and skills, see the [OpenClaw documentation](https://docs.openclaw.ai/).

## Teardown

```bash
./scripts/destroy.sh
```

This destroys all DigitalOcean resources and cleans up the generated Ansible inventory.

## Security Notes

- Root SSH login is disabled after initial provisioning
- Password authentication is disabled (key-only)
- UFW firewall is configured with deny-by-default for inbound
- fail2ban protects against SSH brute-force attacks
- Unattended security upgrades are enabled
- The `openclaw` user runs the gateway (not root)
- Gateway token is auto-generated with 256 bits of entropy
- In `ssh_tunnel` mode, no application ports are exposed to the internet
