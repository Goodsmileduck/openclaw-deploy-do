# OpenClaw DigitalOcean IaC

## OpenClaw Documentation

Main docs: https://docs.openclaw.ai/

Key references:
- Model providers: https://docs.openclaw.ai/concepts/model-providers
- Gateway config: https://docs.openclaw.ai/gateway/configuration
- Authentication: https://docs.openclaw.ai/gateway/authentication
- Full docs index: https://docs.openclaw.ai/llms.txt

## Build / Validate Commands

```bash
# Terraform
cd terraform && terraform init && terraform validate

# Terraform tests (plan-level, no DO token needed)
cd terraform && terraform test

# Ansible (installed in venv)
cd ansible && ansible-playbook playbook.yml --syntax-check
```

## Project Structure

```
terraform/          # Flat Terraform root module (no nested modules)
  versions.tf       # Terraform >= 1.14.0, DO + local providers
  providers.tf      # DigitalOcean provider config
  variables.tf      # All input variables with defaults + validation
  main.tf           # Resources: droplet, firewall, SSH key, project, DNS, generated Ansible files
  outputs.tf        # Droplet IP, gateway URL, SSH command
  terraform.tfvars.example
  tests/              # terraform test files (.tftest.hcl) — mock provider, no real API calls
    setup.tftest.hcl        # Smoke test: plan succeeds with basic config
    variables.tftest.hcl    # access_method + llm_providers validation (valid/invalid values)
    firewall.tftest.hcl     # Conditional inbound rules per access_method
    dns.tftest.hcl          # DNS resources conditional on domain_name
    outputs.tftest.hcl      # gateway_url format, output passthrough

.github/workflows/
  validate.yml        # PR pipeline: terraform (init, fmt, validate, test) + ansible syntax check

ansible/            # Ansible with roles-based structure
  playbook.yml      # Main playbook — conditionally includes roles
  group_vars/all.yml # Default variable values
  inventory.ini.example
  roles/
    common/         # User, SSH hardening, UFW, fail2ban
    docker/         # Docker CE installation
    openclaw/       # Native Node.js install, systemd service, config templates
    traefik/        # Separate Traefik docker-compose at /opt/traefik/ (https only)
    tailscale/      # Mesh VPN (enable_tailscale boolean)
    backup/         # Native restic backup scheduling via systemd timer (enable_backup boolean)

scripts/
  deploy.sh         # Orchestrates terraform apply → ansible-playbook
  destroy.sh        # Tears down all infrastructure
  openclaw-cmd.sh   # Run openclaw CLI commands on server via SSH
  openclaw-tunnel.sh # SSH tunnel manager for local openclaw CLI usage
```

## Key Conventions

- **Terraform:** Flat root module, no nested modules. All resources in `main.tf`.
- **Ansible:** Roles-based. Each role has `tasks/main.yml`, optional `handlers/main.yml` and `templates/`.
- **Templates:** Jinja2 (`.j2` extension) for Ansible templates.
- **Native deployment:** OpenClaw gateway runs natively via Node.js + pnpm as a systemd service (`openclaw-gateway`). Docker is used for agent sandboxing and Traefik (at `/opt/traefik/`). Restic runs natively via apt.
- **Conditional roles:** traefik applied when `access_method == "https"`, tailscale when `enable_tailscale`, backup when `enable_backup`.
- **Ubuntu 24.04:** SSH service is `ssh`, not `sshd`.
- **AI-ASSISTED-SETUP.md:** After any change to variables, scripts, roles, access methods, or deployment flow, update `AI-ASSISTED-SETUP.md` to keep the AI-assisted prompts and reference tables accurate.

## Terraform Testing

- **Framework:** Native `terraform test` with `mock_provider "digitalocean" {}` + `mock_provider "local" {}` — no real API calls, no DO token needed.
- **tfvars auto-loading:** `terraform test` auto-loads `terraform.tfvars` if present. Tests must explicitly set variables in `run` blocks to stay deterministic. Only `do_token` and `ssh_public_key_path` go in the file-level `variables` block.
- **SSH key dependency:** `main.tf` uses `file(pathexpand(var.ssh_public_key_path))` which runs even with mock providers. Tests use `~/.ssh/id_do_ssh.pub` locally; CI generates a dummy key via `ssh-keygen`.
- **CI pipeline:** `.github/workflows/validate.yml` runs on PRs to main. Two parallel jobs: terraform (init, fmt, validate, test) and ansible (syntax check). No secrets required.

## Variable Flow

`terraform.tfvars` → Terraform generates `ansible/terraform_vars.yml` (sensitive) + `ansible/inventory.ini` → `scripts/deploy.sh` runs Terraform then Ansible → Ansible reads `group_vars/all.yml` overridden by `terraform_vars.yml`. Ansible-only secrets (e.g. `tailscale_auth_key`, `acme_dns_token`, `spaces_*`) still use `--extra-vars` or ansible-vault.

## Key Variables

### Terraform variables (flow to Ansible via `terraform_vars.yml`)

| Variable | Default | Description |
|----------|---------|-------------|
| `do_token` | — | DigitalOcean API token (sensitive) |
| `ssh_public_key_path` | `~/.ssh/id_do_ssh.pub` | Path to SSH public key |
| `region` | `nyc3` | DigitalOcean region |
| `droplet_size` | `s-2vcpu-4gb` | Droplet size slug |
| `droplet_name` | `openclaw-server` | Droplet name |
| `access_method` | `ssh_tunnel` | `ssh_tunnel` or `https` |
| `enable_tailscale` | `false` | Combinable with any access_method |
| `domain_name` | `""` | Required when `access_method == "https"` |
| `project_name` | `OpenClaw` | DigitalOcean project name |
| `claude_setup_token` | `""` | Claude setup token (sensitive) |
| `telegram_bot_token` | `""` | Telegram bot token (sensitive) |
| `openclaw_version` | `"latest"` | OpenClaw npm package version |
| `sandbox_mode` | `"non-main"` | Agent sandbox: `off`, `non-main`, `all` |
| `llm_providers` | `[]` | List of `{ name, api_key, model }` — first is primary |

### Ansible-only variables (in `group_vars/all.yml`, via `--extra-vars` or ansible-vault)

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_backup` | `false` | Restic backup to DO Spaces |
| `enable_control_ui` | `true` | OpenClaw Control UI at `/openclaw` |
| `acme_email` | `""` | ACME email (for https) |
| `acme_challenge` | `dns` | `dns` or `http` |
| `acme_dns_token` | `""` | DO API token for DNS-01 challenge |
| `openclaw_channels` | `[]` | List: whatsapp, telegram, discord, slack, signal, mattermost, web |
| `tailscale_auth_key` | `""` | Tailscale pre-auth key |
| `spaces_access_key_id` | `""` | DO Spaces access key (for backup) |
| `spaces_secret_access_key` | `""` | DO Spaces secret key (for backup) |

## LLM Authentication

The `llm_providers` list is optional. Supported approaches:
- Set `llm_providers` in `terraform.tfvars` (flows to Ansible via `terraform_vars.yml`)
- Use Claude setup-token at deploy: set `claude_setup_token` in `terraform.tfvars` (writes `auth-profiles.json` automatically)
- Use Claude setup-token post-deploy: `claude setup-token` then `openclaw models auth paste-token --provider anthropic`
- Supported providers: `anthropic`, `openai`, `openrouter`, `gemini`, `do_ai`, `gradient`, `custom`

## OpenClaw Config Schema (openclaw.json)

Critical schema rules discovered through deployment:
- **`agents.defaults.model`** must be an **object** `{ "primary": "provider/model" }`, NOT a plain string. A string causes a validation error and the gateway refuses to start.
- **`gateway.auth`** is the current structure: `{ "mode": "token", "token": "..." }`. The old flat `gateway.token` is deprecated.
- **Deprecated keys** that cause `doctor --fix` warnings: `agent.model` (use `agents.defaults`), `dm`.
- OpenClaw's `doctor --fix` auto-enriches valid config (adds `groupPolicy`, `streamMode`, `plugins.entries`, `meta`) but will NOT fix schema violations.
- The `channels.telegram` block only needs `enabled`, `botToken`, `dmPolicy` — OpenClaw adds the rest.

## Auth Profiles (auth-profiles.json)

- Path: `~/.openclaw/agents/main/agent/auth-profiles.json`
- Format for setup-token:
  ```json
  {
    "version": 1,
    "profiles": {
      "anthropic:manual": {
        "type": "token",
        "provider": "anthropic",
        "token": "<setup-token>"
      }
    }
  }
  ```
- Setup tokens (`sk-ant-oat01-*`) are OAuth Access Tokens with limited lifetime — they expire and need regeneration via `claude setup-token`.
- The `openclaw models auth setup-token` and `paste-token` commands both require an interactive TTY — they cannot accept piped input. Direct file write is the only automation path.
- To update a token on a running server: write the file, then `sudo systemctl restart openclaw-gateway`.

## Jinja2 Template Gotchas

- **`default()` filter does NOT trigger on empty strings**, only on undefined variables. Use `or` instead: `{{ llm_model or 'anthropic/claude-opus-4-6' }}`.

## Deployment Notes

- **Ansible venv**: `ansible-playbook` lives in `~/.ansible-venv/bin/`. The `deploy.sh` script auto-activates the venv if not in PATH.
- **SSH key**: Terraform derives private key path from `ssh_public_key_path` (strips `.pub` suffix) and writes it into `inventory.ini`.
- **First deploy** uses `ansible_user=root`. After the common role runs, root SSH is disabled — re-runs need `ansible_user=openclaw` with `ansible_become=true`.
- **Current server**: `146.190.86.54` (sgp1 region).
- **Gateway management**: `sudo systemctl status|restart openclaw-gateway` and `sudo journalctl -u openclaw-gateway -f`.
- **Traefik** (https only): `sudo docker compose -f /opt/traefik/docker-compose.yml ps|logs|restart`.
- **Remote openclaw commands (one-off)**: `./scripts/openclaw-cmd.sh <subcommand> [args]` (use `-i` for interactive, e.g. WhatsApp login).
- **Remote openclaw commands (tunnel)**: `./scripts/openclaw-tunnel.sh start` then use `openclaw` locally (requires local install).

## Telegram Bot

- Pairing flow: user sends `/start` to bot, receives a pairing code, then approve on server: `openclaw pairing approve telegram <CODE>`.
- DM policy `pairing` requires explicit approval per user.
