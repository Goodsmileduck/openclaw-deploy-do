# OpenClaw DigitalOcean IaC

Infrastructure as Code for deploying [OpenClaw](https://docs.openclaw.ai/) to a DigitalOcean Droplet. Uses Terraform to provision infrastructure (Droplet, firewall, SSH key, optional DNS) and Ansible to configure the server with OpenClaw (native Node.js), Docker (for agent sandboxing and Traefik), and your choice of access method.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.14.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) >= 2.15
- A [DigitalOcean](https://www.digitalocean.com/) account and API token
- An SSH key pair (configurable via `ssh_public_key_path`, default `~/.ssh/id_do_ssh.pub`)
- An LLM API key or Claude subscription (see [LLM Authentication](#llm-authentication))

## Quick Start

### 1. Configure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your DO token, SSH key path, region, and LLM provider
```

### 2. Deploy

```bash
./scripts/deploy.sh
```

The deploy script runs Terraform (provisions infrastructure, generates Ansible inventory and vars), waits for SSH, then runs the Ansible playbook. Any extra arguments are passed to `ansible-playbook`.

### 3. Connect

**SSH Tunnel (default):**
```bash
# Manual tunnel
ssh -L 18789:localhost:18789 openclaw@<droplet-ip>
# Then open http://localhost:18789

# Or use the helper script
./scripts/openclaw-tunnel.sh start
# Gateway at http://localhost:18789, Control UI at http://localhost:18789/openclaw
```

**HTTPS:** Open `https://your-domain.com` directly (requires `access_method = "https"` and DNS configuration).

**Tailscale:** Available on your Tailscale network when `enable_tailscale = true` (combinable with any access method).

## LLM Authentication

OpenClaw supports multiple LLM providers. See the [model providers docs](https://docs.openclaw.ai/concepts/model-providers) for full details.

### Option A: LLM Providers List (in terraform.tfvars)

```hcl
llm_providers = [
  { name = "anthropic", api_key = "sk-ant-..." },
  { name = "openai", api_key = "sk-..." },
  { name = "openrouter", api_key = "sk-or-..." },
]
```

The first entry becomes the primary model. Supported providers: `anthropic`, `openai`, `openrouter`, `gemini`, `do_ai`, `gradient`, `custom`.

### Option B: Claude Setup Token (in terraform.tfvars)

If you have a Claude Pro or Max subscription, set the setup token instead of an API key:

```hcl
claude_setup_token = "sk-ant-oat01-..."
```

Generate a token locally with `claude setup-token`. Note: setup tokens expire and may need regeneration.

### Option C: Claude Setup Token (post-deploy)

Deploy without credentials, then write the token file on the server:

```bash
ssh openclaw@<droplet-ip>
# Write auth-profiles.json manually (the paste-token TUI command cannot be scripted)
sudo systemctl restart openclaw-gateway
```

See the [authentication docs](https://docs.openclaw.ai/gateway/authentication) for more details.

## Configuration Reference

### Terraform Variables (`terraform/terraform.tfvars`)

These flow to Ansible automatically via a generated `terraform_vars.yml` file.

| Variable | Default | Description |
|---|---|---|
| `do_token` | (required) | DigitalOcean API token |
| `ssh_public_key_path` | `~/.ssh/id_do_ssh.pub` | Path to SSH public key |
| `region` | `nyc3` | DigitalOcean region |
| `droplet_size` | `s-2vcpu-4gb` | Droplet size slug |
| `droplet_name` | `openclaw-server` | Name for the Droplet |
| `access_method` | `ssh_tunnel` | `ssh_tunnel` or `https` |
| `enable_tailscale` | `false` | Enable Tailscale VPN (combinable with any access method) |
| `domain_name` | `""` | Domain for HTTPS (required when `access_method = "https"`) |
| `project_name` | `OpenClaw` | DigitalOcean project name |
| `claude_setup_token` | `""` | Claude setup token |
| `telegram_bot_token` | `""` | Telegram bot token from @BotFather |
| `openclaw_version` | `"latest"` | OpenClaw npm package version |
| `sandbox_mode` | `"non-main"` | Agent sandbox: `off`, `non-main`, `all` |
| `llm_providers` | `[]` | List of `{ name, api_key, model }` -- first is primary |

### Ansible-Only Variables (`ansible/group_vars/all.yml`)

These are configured via `--extra-vars`, ansible-vault, or by editing `group_vars/all.yml` directly.

| Variable | Default | Description |
|---|---|---|
| `enable_backup` | `false` | Restic backup to DO Spaces |
| `enable_control_ui` | `true` | OpenClaw Control UI at `/openclaw` |
| `acme_email` | `""` | ACME email for TLS certificates |
| `acme_challenge` | `dns` | ACME challenge type: `dns` or `http` |
| `acme_dns_token` | `""` | DO API token scoped to DNS (for dns-01 challenge) |
| `openclaw_channels` | `[]` | Channel integrations: whatsapp, telegram, discord, slack, signal, mattermost, web |
| `tailscale_auth_key` | `""` | Tailscale pre-auth key (required when `enable_tailscale = true`) |
| `spaces_access_key_id` | `""` | DO Spaces access key (for backup) |
| `spaces_secret_access_key` | `""` | DO Spaces secret key (for backup) |

## Access Methods

### SSH Tunnel (default)

The most secure option. No ports are exposed beyond SSH.

```bash
ssh -L 18789:localhost:18789 openclaw@<droplet-ip>
```

### HTTPS

Publicly accessible with TLS via Traefik + ACME. Requires a domain name with DNS managed by DigitalOcean.

```hcl
# In terraform.tfvars
access_method = "https"
domain_name   = "openclaw.example.com"
```

```bash
# Deploy with ACME settings
./scripts/deploy.sh --extra-vars "acme_email=you@example.com acme_dns_token=dop_v1_..."
```

### Tailscale

Tailscale is not an access method but a separate overlay. Enable it alongside any access method:

```hcl
# In terraform.tfvars
enable_tailscale = true
```

```bash
./scripts/deploy.sh --extra-vars "tailscale_auth_key=tskey-auth-..."
```

## Helper Scripts

| Script | Description |
|---|---|
| `scripts/deploy.sh` | Runs Terraform then Ansible. Extra args forwarded to `ansible-playbook`. |
| `scripts/destroy.sh` | Destroys all DigitalOcean resources and cleans up generated files. |
| `scripts/openclaw-cmd.sh` | Run openclaw CLI commands on the server via SSH. Use `-i` for interactive. |
| `scripts/openclaw-tunnel.sh` | Manage an SSH tunnel (`start`, `stop`, `status`) for local openclaw CLI usage. |

## Post-Deploy

### Server Management

```bash
# Gateway status / logs
ssh openclaw@<droplet-ip>
sudo systemctl status openclaw-gateway
sudo journalctl -u openclaw-gateway -f

# Remote openclaw commands
./scripts/openclaw-cmd.sh doctor
./scripts/openclaw-cmd.sh channels status --probe
./scripts/openclaw-cmd.sh -i channels login --channel whatsapp
```

### Telegram Bot

1. Create a bot via @BotFather and set `telegram_bot_token` in `terraform.tfvars`
2. User sends `/start` to the bot and receives a pairing code
3. Approve on server: `./scripts/openclaw-cmd.sh pairing approve telegram <CODE>`

## Teardown

```bash
./scripts/destroy.sh
```

This destroys all DigitalOcean resources and cleans up the generated Ansible inventory and vars files.

## Security Notes

- Root SSH login is disabled after initial provisioning
- Password authentication is disabled (key-only)
- UFW firewall is configured with deny-by-default for inbound
- fail2ban protects against SSH brute-force attacks
- Unattended security upgrades are enabled
- The `openclaw` user runs the gateway (not root)
- Gateway token is auto-generated with 256 bits of entropy
- In `ssh_tunnel` mode, no application ports are exposed to the internet
- Docker is used for agent sandboxing (configurable via `sandbox_mode`)
