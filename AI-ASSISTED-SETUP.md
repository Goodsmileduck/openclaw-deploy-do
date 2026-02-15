# AI-Assisted OpenClaw Setup (DigitalOcean Droplet)

This guide enables AI coding assistants (Claude Code, Cursor, Codex, Gemini, etc.) to deploy and configure OpenClaw on a DigitalOcean Droplet using Terraform + Ansible.

## Overview

- Uses **Terraform** for infrastructure provisioning (droplet, firewall, DNS)
- Uses **Ansible** for server configuration (hardening, Docker, OpenClaw, optional Traefik/Tailscale/backup)
- Orchestrated via `scripts/deploy.sh` which runs both in sequence
- Two access methods: SSH tunnel (default), HTTPS (via Traefik)
- Tailscale can be enabled alongside either access method
- Optional encrypted backup to DO Spaces via restic

## Prerequisites

Before asking your AI assistant to deploy OpenClaw:

```bash
# 1. Install Terraform (>= 1.14.0)
# macOS:
brew install terraform
# Linux:
sudo apt-get install -y terraform

# 2. Install Ansible (in a virtualenv)
python3 -m venv .venv && source .venv/bin/activate
pip install ansible

# 3. Have a DigitalOcean API token
# Get one at: https://cloud.digitalocean.com/account/api/tokens

# 4. Have an SSH key pair
# Default expected path: ~/.ssh/id_do_ssh.pub
# Generate if needed: ssh-keygen -t ed25519 -f ~/.ssh/id_do_ssh

# 5. Clone this repo
git clone <this-repo-url>
cd openclaw-do
```

---

## Stage 1: SSH Tunnel (Default, Most Secure)

The simplest deployment — access the gateway only through an SSH tunnel. No ports exposed beyond SSH.

**Cost:** ~$24/mo (s-2vcpu-4gb droplet)

### Prompt

```
Deploy OpenClaw to a DigitalOcean Droplet using the SSH tunnel access method.

1. Create terraform/terraform.tfvars with:
   - do_token = "<my-do-token>"
   - access_method = "ssh_tunnel"
   - region = "nyc3"
   - droplet_size = "s-2vcpu-4gb"

2. Run the deployment:
   ./scripts/deploy.sh

3. After deployment completes, show me:
   - The SSH command to connect
   - How to set up the SSH tunnel for gateway access
   - How to verify the gateway is running
   - The Control UI URL (http://localhost:18789/openclaw via tunnel)

I'll provide my DigitalOcean API token when prompted.
```

### Verification

```bash
# SSH into the server
ssh openclaw@<droplet-ip>

# Check gateway status
sudo docker compose -f /opt/openclaw/docker-compose.yml ps

# Set up SSH tunnel (from local machine)
ssh -L 18789:localhost:18789 openclaw@<droplet-ip>

# Access gateway at http://localhost:18789
# Control UI at http://localhost:18789/openclaw
```

---

## Stage 2: Tailscale (Private Network Add-On)

Enable Tailscale mesh VPN alongside any access method — accessible from any device on your tailnet.

**Cost:** ~$24/mo + Tailscale (free tier available)

### Prompt

```
Deploy OpenClaw to a DigitalOcean Droplet with Tailscale enabled.

1. Create terraform/terraform.tfvars with:
   - do_token = "<my-do-token>"
   - access_method = "ssh_tunnel"
   - enable_tailscale = true
   - region = "nyc3"
   - droplet_size = "s-2vcpu-4gb"

2. I have a Tailscale pre-auth key ready: <my-tailscale-key>

3. Run the deployment:
   ./scripts/deploy.sh --extra-vars "tailscale_auth_key=<my-tailscale-key>"

4. After deployment:
   - Show me the Tailscale hostname
   - Verify gateway is accessible on the tailnet
   - Show me how to connect from my devices

Reference the tailscale role in ansible/roles/tailscale/ for the setup.
```

### Getting a Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate a new auth key (reusable recommended)

### Verification

```bash
# SSH into server
ssh openclaw@<droplet-ip>

# Check Tailscale status
sudo tailscale status

# Access gateway via Tailscale
# From any device on your tailnet:
# http://<tailscale-hostname>:18789
```

---

## Stage 3: HTTPS with Domain (Public Access)

Public access with TLS — requires a domain name. Traefik v3 reverse proxy handles HTTPS with auto-renewed Let's Encrypt certificates. Supports DNS-01 (default) or HTTP-01 ACME challenge.

**Cost:** ~$24/mo + domain

### Prompt (DNS-01 Challenge — Default)

```
Deploy OpenClaw to a DigitalOcean Droplet with HTTPS public access using DNS challenge.

1. Create terraform/terraform.tfvars with:
   - do_token = "<my-do-token>"
   - access_method = "https"
   - domain_name = "<my-domain.com>"
   - region = "nyc3"
   - droplet_size = "s-2vcpu-4gb"

2. Run the deployment:
   ./scripts/deploy.sh --extra-vars "acme_email=<my-email> acme_dns_token=<my-do-dns-token>"

3. After deployment:
   - Verify DNS is pointing to the droplet
   - Verify the TLS certificate was obtained
   - Show me the HTTPS URL to access the gateway
   - Control UI at https://<my-domain>/openclaw

Reference:
- ansible/roles/traefik/ for the reverse proxy setup
- terraform/main.tf for DNS resource creation
```

### Prompt (HTTP-01 Challenge)

```
Deploy OpenClaw with HTTPS using HTTP challenge (no DNS token needed).

1. Create terraform/terraform.tfvars with:
   - do_token = "<my-do-token>"
   - access_method = "https"
   - domain_name = "<my-domain.com>"
   - region = "nyc3"

2. Run the deployment:
   ./scripts/deploy.sh --extra-vars "acme_email=<my-email> acme_challenge=http"

Note: DNS must already point to the droplet IP before deployment.
```

### DNS Setup

If your domain is managed by DigitalOcean, Terraform creates the DNS record automatically. Otherwise, point your domain's A record to the droplet IP shown in the Terraform output.

### Verification

```bash
# SSH into server
ssh openclaw@<droplet-ip>

# Check Traefik container
docker ps | grep traefik

# Check certificate (visit in browser or)
curl -I https://<your-domain>

# Access gateway at https://<your-domain>
# Control UI at https://<your-domain>/openclaw
```

---

## LLM Authentication

OpenClaw needs an LLM provider to function. Choose one of these approaches.

### Option A: API Key at Deploy Time

Pass the key directly during deployment.

#### Prompt

```
Deploy OpenClaw with my Anthropic API key.

Run the deployment with:
./scripts/deploy.sh --extra-vars "llm_api_key=<my-api-key>"

Or for a different provider:
./scripts/deploy.sh --extra-vars "llm_provider=openai llm_api_key=<my-openai-key>"

# For DigitalOcean AI:
./scripts/deploy.sh --extra-vars "llm_provider=do_ai llm_api_key=<my-do-ai-key>"

After deployment, verify the LLM connection:
- SSH into the server
- Check the gateway logs for successful provider initialization
- Run a test query if possible

Supported providers: anthropic, openai, openrouter, gemini, do_ai, gradient, custom
```

### Option B: Claude Setup Token (Pro/Max Subscription)

Use a Claude subscription instead of an API key.

#### Prompt

```
Deploy OpenClaw with Claude setup-token authentication.

1. Add claude_setup_token to terraform/terraform.tfvars:
   - claude_setup_token = "<my-setup-token>"

2. Run the deployment:
   ./scripts/deploy.sh

3. After deployment, SSH into the server and complete auth setup:
   ssh openclaw@<droplet-ip>
   ./setup-claude-token.sh

4. Verify the connection is working.

Reference the setup-claude-token.sh helper script on the server at
/home/openclaw/setup-claude-token.sh
```

### Option C: Configure Later

Deploy without any LLM key and add it post-deploy.

#### Prompt

```
Deploy OpenClaw without an LLM key — I'll configure it later.

1. Run the deployment normally:
   ./scripts/deploy.sh

2. After deployment, show me how to:
   - SSH into the server
   - Add an API key to /etc/openclaw/gateway.env
   - Restart the gateway container
   - Verify the LLM connection

The gateway will start but won't be able to process LLM requests until a key is added.
```

---

## Channel Setup

Channels can be configured via the `openclaw_channels` list variable or individually (e.g., Telegram bot token).

### Enable Channels at Deploy Time

#### Prompt

```
Deploy OpenClaw with Telegram and Discord channels enabled.

Run the deployment with:
./scripts/deploy.sh --extra-vars '{"openclaw_channels": ["telegram", "discord"]}'

After deployment:
- Configure channel credentials via the Control UI at /openclaw
- Or SSH in and edit ~/.openclaw/openclaw.json directly
```

### Telegram Bot (with Token)

#### Prompt

```
Add a Telegram bot channel to my OpenClaw deployment.

1. Add telegram_bot_token to terraform/terraform.tfvars:
   - telegram_bot_token = "<my-bot-token>"

2. Re-run the deployment to apply:
   ./scripts/deploy.sh

3. After deployment:
   - Verify the Telegram channel is configured in openclaw.json
   - Check the gateway logs for Telegram connection
   - Send a test message to my bot

Reference ansible/roles/openclaw/templates/openclaw.json.j2 for the Telegram config.
```

### Getting a Telegram Bot Token

1. Open Telegram and message [@BotFather](https://t.me/BotFather)
2. Send `/newbot` and follow the prompts
3. Copy the bot token

### WhatsApp Setup

WhatsApp requires scanning a QR code, which is challenging for AI assistants.

#### Prompt

```
Help me connect WhatsApp to my OpenClaw deployment.

1. SSH into the server:
   ssh openclaw@<droplet-ip>

2. Run the WhatsApp login command:
   openclaw channels login --channel whatsapp

3. I'll scan the QR code with my phone.
   Walk me through the process:
   - What to look for in WhatsApp settings
   - How to scan the QR code
   - How to verify the connection

4. After linking:
   - Restart the gateway: sudo docker compose -f /opt/openclaw/docker-compose.yml restart openclaw
   - Verify: openclaw channels status --probe
   - Send a test message

Note: The QR code step requires my manual interaction —
guide me through it step by step.
```

### Verification

```bash
# Check channel status
openclaw channels status --probe
# Should show channels as linked and connected

# View gateway logs
sudo journalctl -u openclaw-gateway -f
```

---

## Backup to DO Spaces

Enable encrypted incremental backups of OpenClaw data to DigitalOcean Spaces using restic.

### Prompt

```
Enable backup for my OpenClaw deployment.

1. Create a DO Spaces bucket named "openclaw-backups" in your region
2. Generate Spaces access keys at:
   https://cloud.digitalocean.com/account/api/spaces

3. Run deployment with backup enabled:
   ./scripts/deploy.sh --extra-vars "enable_backup=true spaces_access_key_id=<key> spaces_secret_access_key=<secret>"

4. After deployment:
   - Note the restic password displayed (SAVE IT!)
   - Verify the backup timer is active
   - Check backup status

Reference ansible/roles/backup/ for the restic setup.
```

### Verification

```bash
# SSH into server
ssh openclaw@<droplet-ip>

# Check timer status
sudo systemctl status openclaw-backup.timer

# List backup snapshots
source ~/.restic-env && restic snapshots

# Run a manual backup
sudo systemctl start openclaw-backup.service
```

---

## Changing Access Method

You can switch between access methods by updating the configuration and re-deploying.

### Prompt

```
Switch my OpenClaw deployment from SSH tunnel to https.

1. Update terraform/terraform.tfvars:
   - access_method = "https"
   - domain_name = "<my-domain.com>"

2. Re-run:
   ./scripts/deploy.sh --extra-vars "acme_email=<my-email> acme_dns_token=<my-do-dns-token>"

3. Verify the new access method is working.
4. Confirm firewall rules were updated correctly.
```

---

## Destroying Infrastructure

### Prompt

```
Tear down my OpenClaw deployment completely.

Run: ./scripts/destroy.sh

This will:
- Destroy the DigitalOcean droplet
- Remove the firewall rules
- Remove DNS records (if any)
- Clean up the generated Ansible inventory

Confirm before proceeding — this is irreversible.
```

---

## Deployment Modes

| Mode             | When to Use                              |
| ---------------- | ---------------------------------------- |
| **deploy.sh**    | Full deploy: Terraform + Ansible         |
| **Terraform only** | Infrastructure changes (resize, region) |
| **Ansible only** | Config changes (new channel, update key) |

### Terraform Only

```bash
cd terraform && terraform apply
```

### Ansible Only

```bash
cd ansible && ansible-playbook -i inventory.ini playbook.yml
```

---

## Reference

### Key Files

| File | Purpose |
| --- | --- |
| `scripts/deploy.sh` | End-to-end deployment orchestrator |
| `scripts/destroy.sh` | Infrastructure teardown |
| `terraform/terraform.tfvars.example` | Example Terraform config |
| `terraform/variables.tf` | All input variables with validation |
| `ansible/group_vars/all.yml` | Default Ansible variables |
| `ansible/playbook.yml` | Main Ansible playbook |
| `ansible/roles/traefik/` | Traefik v3 reverse proxy (replaces nginx) |
| `ansible/roles/backup/` | Restic backup to DO Spaces |
| `CLAUDE.md` | Project conventions for AI assistants |

### Important Commands

```bash
# Deployment
./scripts/deploy.sh                                    # Full deploy
./scripts/deploy.sh --extra-vars "llm_api_key=sk-..."  # Deploy with API key
./scripts/destroy.sh                                   # Tear down everything

# Server management (after SSH)
sudo docker compose -f /opt/openclaw/docker-compose.yml ps       # Check container status
sudo docker compose -f /opt/openclaw/docker-compose.yml restart  # Restart all services
sudo docker compose -f /opt/openclaw/docker-compose.yml logs -f  # Follow logs

# Backup
sudo systemctl status openclaw-backup.timer   # Check backup timer
sudo docker compose -f /opt/openclaw/docker-compose.yml run --rm restic restic snapshots  # List snapshots

# OpenClaw commands (on server)
openclaw gateway health --url ws://127.0.0.1:18789
openclaw channels status --probe
openclaw channels login --channel whatsapp

# SSH tunnel for gateway access
ssh -L 18789:localhost:18789 openclaw@<droplet-ip>
```

### Troubleshooting

| Issue | Solution |
| --- | --- |
| Terraform fails with auth error | Verify `do_token` in `terraform.tfvars` |
| Ansible can't connect | Wait for droplet boot; check SSH key path |
| Gateway not starting | Check logs: `sudo docker compose -f /opt/openclaw/docker-compose.yml logs openclaw` |
| LLM requests failing | Verify API key in `/etc/openclaw/gateway.env` |
| Traefik not starting | Check `sudo docker compose -f /opt/openclaw/docker-compose.yml logs traefik`; verify ports 80/443 not in use |
| TLS certificate fails (DNS) | Verify `acme_dns_token` has DNS write access |
| TLS certificate fails (HTTP) | Ensure DNS points to droplet IP, port 80 open |
| Tailscale not connecting | Check auth key validity and `tailscale status` |
| Backup failing | Check `sudo docker compose -f /opt/openclaw/docker-compose.yml run --rm restic restic check`; verify Spaces credentials |
| WhatsApp disconnected | Re-run `openclaw channels login --channel whatsapp` |
| Control UI not loading | Verify `enable_control_ui: true` in config |

### Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                 Local Machine                    │
│                                                  │
│  terraform.tfvars ──► deploy.sh ──► inventory.ini│
│                          │                       │
│              ┌───────────┴───────────┐           │
│              ▼                       ▼           │
│         Terraform              Ansible           │
│      (provisions DO           (configures        │
│       infrastructure)          server)            │
└──────────────┬───────────────────┬───────────────┘
               │                   │
               ▼                   ▼
┌─────────────────────────────────────────────────┐
│            DigitalOcean Droplet                  │
│                                                  │
│  ┌──────────┐  ┌─────────┐                       │
│  │   UFW    │  │ fail2ban│                       │
│  │ Firewall │  │         │                       │
│  └──────────┘  └─────────┘                       │
│                                                  │
│  ┌─── Docker Compose (/opt/openclaw/) ────────┐  │
│  │                                             │  │
│  │  ┌──────────────────────────────────────┐   │  │
│  │  │   OpenClaw Gateway (:18789)          │   │  │
│  │  │   ghcr.io/openclaw/openclaw:latest   │   │  │
│  │  │  ┌─────────┐ ┌──────────┐ ┌──────┐  │   │  │
│  │  │  │Anthropic│ │ Channels │ │CtrlUI│  │   │  │
│  │  │  │ OpenAI  │ │ Telegram │ │/open │  │   │  │
│  │  │  │ DO AI   │ │ WhatsApp │ │ claw │  │   │  │
│  │  │  └─────────┘ └──────────┘ └──────┘  │   │  │
│  │  └──────────────────────────────────────┘   │  │
│  │                                             │  │
│  │  ┌──────────┐  ┌──────────┐                 │  │
│  │  │ Traefik  │  │  Restic  │                 │  │
│  │  │ (https)  │  │ (backup) │                 │  │
│  │  └──────────┘  └──────────┘                 │  │
│  └─────────────────────────────────────────────┘  │
│                                                  │
│  ┌───────────────┐                               │
│  │  Tailscale    │  (native, optional)           │
│  └───────────────┘                               │
└─────────────────────────────────────────────────┘
```

### External Resources

- [OpenClaw Documentation](https://docs.openclaw.ai)
- [OpenClaw Gateway Config](https://docs.openclaw.ai/gateway/configuration)
- [OpenClaw Authentication](https://docs.openclaw.ai/gateway/authentication)
- [DigitalOcean Droplet Docs](https://docs.digitalocean.com/products/droplets/)
- [Terraform DigitalOcean Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [Traefik v3 Documentation](https://doc.traefik.io/traefik/)
- [Restic Documentation](https://restic.readthedocs.io/)
