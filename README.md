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

#### OpenRouter Models

OpenRouter acts as a unified gateway to many LLM providers. Use the `openrouter/` prefix for model IDs. An API key is free to create at [openrouter.ai/keys](https://openrouter.ai/keys).

**Best value models:**

| Model ID | Context | Price (per M tokens) |
|----------|---------|---------------------|
| `openrouter/deepseek/deepseek-v3.2` | 163k | $0.25 / $0.38 |
| `openrouter/mistralai/devstral-2512` | 256k | $0.05 / $0.22 |
| `openrouter/qwen/qwen3-coder-next` | 256k | $0.07 / $0.30 |
| `openrouter/xiaomi/mimo-v2-flash` | 256k | $0.09 / $0.29 |
| `openrouter/bytedance-seed/seed-1.6-flash` | 256k | $0.075 / $0.30 |
| `openrouter/kwaipilot/kat-coder-pro` | 256k | $0.21 / $0.83 |

**Premium models:**

| Model ID | Context | Price (per M tokens) |
|----------|---------|---------------------|
| `openrouter/anthropic/claude-opus-4.6` | 1M | $5 / $25 |
| `openrouter/openai/gpt-5.1-codex` | 400k | $1.25 / $10 |
| `openrouter/google/gemini-3-pro-preview` | 1M | $2 / $12 |
| `openrouter/mistralai/mistral-large-2512` | 256k | $0.50 / $1.50 |

**Free models:**

| Model ID | Context |
|----------|---------|
| `openrouter/stepfun/step-3.5-flash:free` | 256k |
| `openrouter/nvidia/nemotron-3-nano-30b-a3b:free` | 256k |
| `openrouter/arcee-ai/trinity-mini:free` | 131k |

Browse all models at [openrouter.ai/models](https://openrouter.ai/models).

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
| `brave_api_key` | `""` | Brave Search API key for web_search tool |
| `openclaw_version` | `"latest"` | OpenClaw npm package version |
| `sandbox_mode` | `"non-main"` | Agent sandbox: `off`, `non-main`, `all` |
| `custom_image_id` | `""` | Pre-baked snapshot ID (see [Pre-baked Image](#pre-baked-image-optional)) |
| `enable_backup` | `false` | Restic backup to DO Spaces (creates bucket automatically) |
| `spaces_access_key_id` | `""` | DO Spaces access key (required when `enable_backup = true`) |
| `spaces_secret_access_key` | `""` | DO Spaces secret key (required when `enable_backup = true`) |
| `llm_providers` | `[]` | List of `{ name, api_key, model }` -- first is primary |

### Ansible-Only Variables (`ansible/group_vars/all.yml`)

These are configured via `--extra-vars`, ansible-vault, or by editing `group_vars/all.yml` directly.

| Variable | Default | Description |
|---|---|---|
| `enable_browser` | `false` | Chrome + Playwright browser tool for web browsing |
| `enable_control_ui` | `true` | OpenClaw Control UI at `/openclaw` |
| `acme_email` | `""` | ACME email for TLS certificates |
| `acme_challenge` | `dns` | ACME challenge type: `dns` or `http` |
| `acme_dns_token` | `""` | DO API token scoped to DNS (for dns-01 challenge) |
| `openclaw_channels` | `[]` | Channel integrations: whatsapp, telegram, discord, slack, signal, mattermost, web |
| `tailscale_auth_key` | `""` | Tailscale pre-auth key (required when `enable_tailscale = true`) |

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

## Pre-baked Image (Optional)

By default, each deploy installs all packages from scratch on a fresh Ubuntu 24.04 droplet (~15-20 minutes). You can build a custom DigitalOcean snapshot with [Packer](https://www.packer.io/) that pre-installs everything, reducing deploy time to ~3-5 minutes.

### What's Pre-baked

The snapshot includes: Ubuntu 24.04 with security patches, Docker CE, Node.js 22, pnpm, Google Chrome, Tailscale, restic, UFW + fail2ban, SSH hardening, and the `openclaw` user with directory structure. Services are enabled but not started.

### What's NOT Pre-baked

Everything deployment-specific stays in Ansible: SSH authorized keys, OpenClaw CLI (version may vary), all config files, API keys/tokens, Traefik config, service startup.

### Build and Use

```bash
# Install Packer: https://developer.hashicorp.com/packer/install

# Build the snapshot (~7-8 minutes)
cd packer
packer init .
packer build -var "do_token=$DO_TOKEN" .
# Note the snapshot ID from the output

# Use it — add to terraform.tfvars:
# custom_image_id = "<snapshot-id>"

# Deploy as usual
./scripts/deploy.sh
```

### When to Use It

- **Frequent deploys or rebuilds** — saves 10-15 minutes each time
- **CI/CD pipelines** — predictable, faster infrastructure provisioning
- **Testing** — spin up and tear down servers quickly
- **Multiple environments** — same base image across staging/production

### When NOT to Use It

- **One-time deploy** — the build itself takes ~8 minutes, so there's no net savings on a single deploy
- **Heavily customized base OS** — if you need packages or configs not in the standard roles, you'll need to update the Packer scripts separately
- **Cross-region deploys** — snapshots are region-specific; you'd need to build one per region or copy snapshots (adds time/cost)

### Limitations

- **Snapshots are private** — only visible to your DigitalOcean account. Not shareable via URL.
- **Region-bound** — built in one region (default `nyc3`). To use in another region, either build there or copy the snapshot.
- **Maintenance overhead** — when you add packages to an Ansible role, the corresponding Packer script needs updating too. They can drift if not kept in sync.
- **Snapshot storage cost** — DigitalOcean charges $0.06/GB/month for snapshots. The image is ~3-4 GB.
- **No automatic updates** — the image freezes package versions at build time. Security patches come from `unattended-upgrades` after the droplet boots, not from the image itself. Rebuild periodically (the CI workflow runs weekly by default).

### Automated Rebuilds (Optional)

An example CI workflow is included at `.github/workflows/build-image.yml` (disabled by default). To enable automated image builds:

1. Add a `DO_API_TOKEN` secret to your GitHub repository settings
2. Uncomment the `push` and `schedule` triggers in the workflow file
3. The workflow will then rebuild the image on `packer/**` changes, weekly, or via manual dispatch

### Fallback

Leave `custom_image_id` empty (the default) to deploy on vanilla Ubuntu 24.04 with full Ansible installation. The Ansible playbook works identically either way.

## Browser Tool + Web Search

### Browser Tool

Enable the built-in browser tool so agents can browse the web via headless Chrome. Uses OpenClaw's managed `openclaw` browser profile — no Chrome extension needed.

```bash
./scripts/deploy.sh --extra-vars "enable_browser=true"
```

This installs Google Chrome + Playwright on the server and adds the `browser` configuration to `openclaw.json`. Chrome adds ~500MB disk usage.

Verify on the server:
```bash
openclaw browser --browser-profile openclaw status
openclaw browser --browser-profile openclaw start
openclaw browser --browser-profile openclaw open https://example.com
openclaw browser --browser-profile openclaw snapshot
```

See the [browser tool docs](https://docs.openclaw.ai/tools/browser.md) for full details.

### Web Search (Brave Search)

Enable the web search tool with a [Brave Search API key](https://brave.com/search/api/):

```hcl
# In terraform.tfvars
brave_api_key = "BSA-..."
```

The key flows to Ansible via `terraform_vars.yml`, sets the `BRAVE_API_KEY` environment variable, and enables the `tools.web.search` block in `openclaw.json`.

### Both Together

```bash
# Set brave_api_key in terraform.tfvars, then:
./scripts/deploy.sh --extra-vars "enable_browser=true"
```

**Note:** The browser tool requires a model that supports tool use (e.g., Claude, GPT-4o). Free/small models may not invoke it correctly.

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
./scripts/destroy.sh        # interactive confirmation
./scripts/destroy.sh -y     # skip confirmation (or --force)
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
