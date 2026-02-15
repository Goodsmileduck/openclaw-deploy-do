# OpenClaw DigitalOcean IaC — Design Document

**Date**: 2026-02-15
**Status**: Approved

## Goal

Create an Infrastructure as Code repository to deploy OpenClaw (open-source AI assistant) to a DigitalOcean Droplet using Terraform for infrastructure provisioning and Ansible for server configuration.

## Decisions

- **Deploy target**: DigitalOcean Droplet (VM)
- **LLM providers**: Any (Anthropic, OpenAI, Gradient, custom) — fully configurable
- **Channels**: Gateway + channel connection hooks post-deploy
- **Remote access**: User-selectable — SSH tunnel, Tailscale, or direct HTTPS (nginx reverse proxy)
- **Provisioning**: Ansible with roles
- **IaC structure**: Flat (single Terraform root module + Ansible roles)

## Repository Structure

```
openclaw-do/
├── terraform/
│   ├── main.tf              # Droplet, firewall, SSH key, project
│   ├── variables.tf         # All input variables
│   ├── outputs.tf           # IP, connection info for Ansible
│   ├── providers.tf         # DigitalOcean provider config
│   ├── versions.tf          # Terraform + provider version constraints
│   └── terraform.tfvars.example
├── ansible/
│   ├── playbook.yml         # Main entry point
│   ├── inventory.ini.example
│   ├── group_vars/
│   │   └── all.yml          # Default variables
│   └── roles/
│       ├── common/          # Base OS: non-root user, SSH hardening, UFW firewall, fail2ban
│       ├── docker/          # Docker CE install + OpenClaw sandbox config
│       ├── openclaw/        # Node.js 22, OpenClaw install, systemd service, gateway config
│       ├── nginx/           # Reverse proxy + Let's Encrypt (conditional)
│       └── tailscale/       # Tailscale install + serve config (conditional)
├── scripts/
│   ├── deploy.sh            # End-to-end: terraform apply -> generate inventory -> ansible-playbook
│   └── destroy.sh           # Teardown
├── CLAUDE.md
├── README.md
└── .gitignore
```

## Terraform Resources

| Resource | Purpose |
|----------|---------|
| `digitalocean_ssh_key` | Upload user's SSH public key |
| `digitalocean_droplet` | Ubuntu 24.04 LTS, configurable size (default `s-2vcpu-4gb`) |
| `digitalocean_firewall` | Allow SSH (22), OpenClaw gateway (18789), HTTPS (443 conditional), rate limiting |
| `digitalocean_project` | Group resources under a DO project |
| `digitalocean_domain` + `digitalocean_record` | Optional DNS (for HTTPS access) |

**Key Terraform variables**: `do_token`, `ssh_public_key_path`, `region`, `droplet_size`, `access_method` (ssh_tunnel | tailscale | https), `domain_name` (optional).

## Ansible Roles

### `common` — Base hardening
- Create `openclaw` user (no password, sudo access)
- SSH hardening (disable root login, password auth)
- UFW: allow SSH, deny all inbound by default
- fail2ban for SSH brute-force protection
- Unattended upgrades

### `docker` — Container runtime
- Install Docker CE from official repo
- Add `openclaw` user to docker group
- Configure Docker daemon for OpenClaw sandbox mode

### `openclaw` — The application
- Install Node.js 22 via NodeSource
- Install OpenClaw globally via npm
- Generate gateway auth token
- Create `~/.openclaw/openclaw.json` with user's provider config
- Create systemd service (`openclaw-gateway.service`)
- Open firewall port 18789 (loopback or specific interface based on access method)

### `nginx` (conditional: `access_method == "https"`)
- Install nginx
- Configure reverse proxy to `127.0.0.1:18789`
- Certbot/Let's Encrypt for TLS
- Open port 443 in UFW

### `tailscale` (conditional: `access_method == "tailscale"`)
- Install Tailscale
- Configure `tailscale serve` to expose gateway on tailnet
- No public ports opened

## LLM Provider Configuration

Ansible templates `~/.openclaw/openclaw.json` based on variables:

```yaml
llm_provider: "anthropic"                # anthropic | openai | gradient | custom
llm_api_key: ""                          # Set via --extra-vars or ansible-vault
llm_model: "anthropic/claude-opus-4-6"   # Default model
```

## Security Defaults

Matching the DigitalOcean 1-Click tutorial security posture:

- Gateway token auth enabled by default
- Docker sandbox for non-main sessions
- DM pairing mode enabled
- Non-root execution
- UFW rate-limiting on OpenClaw ports

## Deployment Workflow

```
User runs: ./scripts/deploy.sh

  1. terraform init + apply  ->  Creates Droplet, firewall, SSH key
  2. Terraform outputs IP    ->  Auto-generates ansible/inventory.ini
  3. ansible-playbook        ->  Provisions everything on the Droplet
  4. Prints connection info  ->  Gateway URL, access instructions
```
