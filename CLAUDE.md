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

# Packer (validate only — build requires DO token)
cd packer && packer init . && PKR_VAR_do_token=validation-only packer validate .
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
    image.tftest.hcl        # custom_image_id + use_prebaked_image logic
    version.tftest.hcl      # openclaw_version pinning when access_method=https
    ssh_cidrs.tftest.hcl    # SSH source IP restriction validation

packer/               # Packer HCL2 template for pre-baked DigitalOcean snapshot
  openclaw-base.pkr.hcl  # Builder config + provisioner chain
  scripts/               # Shell provisioners (base, docker, nodejs, extras, cleanup)

.github/workflows/
  validate.yml        # PR pipeline: terraform + ansible + packer validation
  build-image.yml     # Packer build: on push to packer/**, weekly schedule, manual dispatch

ansible/            # Ansible with roles-based structure
  playbook.yml      # Main playbook — conditionally includes roles
  group_vars/all.yml # Default variable values
  inventory.ini.example
  roles/
    common/         # User, SSH hardening, UFW, fail2ban, sysctl, unattended-upgrades, journald
    docker/         # Docker CE installation
    openclaw/       # Native Node.js install, systemd service, config templates, health check, alerting
    traefik/        # Separate Traefik docker-compose at /opt/traefik/ (https only), rate limiting, fail2ban
    tailscale/      # Mesh VPN (enable_tailscale boolean)
    backup/         # Native restic backup scheduling via systemd timer (enable_backup boolean), integrity check
    monitoring/     # Beszel server monitoring via Docker (enable_monitoring boolean)

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
- **Conditional roles:** traefik applied when `access_method == "https"`, tailscale when `enable_tailscale`, backup when `enable_backup`, monitoring when `enable_monitoring`.
- **Pre-baked image:** When `use_prebaked_image` is true (set automatically via `custom_image_id`), Ansible skips package installation tasks in all roles (apt, GPG keys, repos). Config templating and service management always run. Equivalent to `--skip-tags install`.
- **Ansible tags:** Every task is tagged for selective runs. See "Ansible Tags" section below.
- **Ubuntu 24.04:** SSH service is `ssh`, not `sshd`.
- **AI-ASSISTED-SETUP.md:** After any change to variables, scripts, roles, access methods, or deployment flow, update `AI-ASSISTED-SETUP.md` to keep the AI-assisted prompts and reference tables accurate.

## Ansible Tags

All tasks are tagged for selective execution. Two layers of tags:

**Role tags** (on `playbook.yml` role includes): `common`, `docker`, `openclaw`, `traefik`, `tailscale`, `backup`, `monitoring`

**Functional tags** (on individual tasks):

| Tag | Purpose | Example tasks |
|-----|---------|---------------|
| `install` | System packages: apt, GPG keys, repos, pnpm setup | Docker CE, Node.js 22, Tailscale, restic |
| `deploy` | Application deployment (always runs, even on pre-baked) | `pnpm install -g openclaw`, Claude Code CLI |
| `config` | Configuration files, templates, directories, user setup | openclaw.json, daemon.json, auth-profiles, user creation |
| `security` | SSH hardening, UFW rules, fail2ban | sshd_config, firewall rules, fail2ban jail |
| `service` | systemd service management | enable/start docker, openclaw-gateway, backup timer |

**Common usage patterns:**
```bash
# Skip package installs (pre-baked image, same as use_prebaked_image=true)
ansible-playbook playbook.yml --skip-tags install

# Only update config and restart services
ansible-playbook playbook.yml --tags config,service

# Only redeploy OpenClaw app (upgrade version)
ansible-playbook playbook.yml --tags openclaw --skip-tags install

# Only run security hardening
ansible-playbook playbook.yml --tags security

# Run a single role
ansible-playbook playbook.yml --tags traefik
```

**Note:** `pre_tasks` (variable loading) and `post_tasks` (deploy info) are tagged `always` — they run regardless of `--tags` filtering.

## Terraform Testing

- **Framework:** Native `terraform test` with `mock_provider "digitalocean" {}` + `mock_provider "local" {}` — no real API calls, no DO token needed.
- **tfvars auto-loading:** `terraform test` auto-loads `terraform.tfvars` if present. Tests must explicitly set variables in `run` blocks to stay deterministic. Only `do_token` and `ssh_public_key_path` go in the file-level `variables` block.
- **SSH key dependency:** `main.tf` uses `file(pathexpand(var.ssh_public_key_path))` which runs even with mock providers. Tests use `~/.ssh/id_do_ssh.pub` locally; CI generates a dummy key via `ssh-keygen`.
- **CI pipeline:** `.github/workflows/validate.yml` runs on PRs to main. Three parallel jobs: terraform (init, fmt, validate, test), ansible (syntax check), packer (init, fmt, validate). No secrets required.

## Packer Image

- **Template:** `packer/openclaw-base.pkr.hcl` — DigitalOcean builder with 5 shell provisioners.
- **Pre-baked contents:** Ubuntu 24.04 + apt upgrade, common packages, Docker CE + daemon.json, Node.js 22 + pnpm, Tailscale, restic, openclaw user + directories, SSH hardening, UFW, fail2ban.
- **Build:** `cd packer && packer init . && packer build -var "do_token=$DO_TOKEN" .`
- **Use:** Set `custom_image_id = "<snapshot-id>"` in `terraform.tfvars`. Terraform automatically passes `use_prebaked_image = true` to Ansible.
- **Fallback:** Leave `custom_image_id` empty (default) for full Ansible install on vanilla Ubuntu.
- **CI:** `.github/workflows/build-image.yml` is an example workflow (disabled by default, only `workflow_dispatch` enabled). Uncomment `push`/`schedule` triggers and add `DO_API_TOKEN` secret to enable automated builds.
- **Maintenance:** Packer scripts mirror the package-install portions of Ansible roles. When adding packages to a role, update the corresponding Packer script.

## Variable Flow

`terraform.tfvars` → Terraform generates `ansible/terraform_vars.yml` (sensitive) + `ansible/inventory.ini` → `scripts/deploy.sh` runs Terraform then Ansible → Ansible reads `group_vars/all.yml` overridden by `terraform_vars.yml`. Ansible-only secrets (e.g. `tailscale_auth_key`, `acme_dns_token`) still use `--extra-vars` or ansible-vault.

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
| `brave_api_key` | `""` | Brave Search API key for web_search tool (sensitive) |
| `openclaw_version` | `"latest"` | OpenClaw npm package version |
| `sandbox_mode` | `"non-main"` | Agent sandbox: `off`, `non-main`, `all` |
| `ssh_allowed_cidrs` | `[]` | CIDRs allowed to SSH (empty = open to all) |
| `custom_image_id` | `""` | Pre-baked snapshot ID (empty = vanilla Ubuntu 24.04) |
| `enable_backup` | `false` | Restic backup to DO Spaces |
| `spaces_access_key_id` | `""` | DO Spaces access key (for backup, sensitive) |
| `spaces_secret_access_key` | `""` | DO Spaces secret key (for backup, sensitive) |
| `llm_providers` | `[]` | List of `{ name, api_key, model }` — first is primary |

### Ansible-only variables (in `group_vars/all.yml`, via `--extra-vars` or ansible-vault)

| Variable | Default | Description |
|----------|---------|-------------|
| `use_prebaked_image` | `false` | Skip package installs (set automatically by Terraform when `custom_image_id` is provided) |
| `enable_monitoring` | `false` | Beszel server monitoring |
| `enable_control_ui` | `true` | OpenClaw Control UI at `/openclaw` |
| `enable_browser` | `false` | Chrome + Playwright browser tool |
| `auto_reboot_time` | `"04:00"` | Automatic reboot time after kernel upgrades (HH:MM) |
| `acme_email` | `""` | ACME email (for https) |
| `acme_challenge` | `dns` | `dns` or `http` |
| `acme_dns_token` | `""` | DO API token for DNS-01 challenge |
| `traefik_rate_limit_average` | `100` | Traefik rate limit requests/sec average |
| `traefik_rate_limit_burst` | `200` | Traefik rate limit burst size |
| `traefik_basic_auth` | `[]` | Traefik basic auth users (htpasswd format) |
| `traefik_fail2ban` | `true` | Enable fail2ban jail for Traefik 401/403/429 |
| `openclaw_channels` | `[]` | List: whatsapp, telegram, discord, slack, signal, mattermost, web |
| `tailscale_auth_key` | `""` | Tailscale pre-auth key |
| `telegram_alert_chat_id` | `""` | Telegram chat ID for service failure alerts |
| `beszel_port` | `8090` | Beszel web UI port |
| `beszel_agent_key` | `""` | Beszel agent key (auto-generated if empty) |

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
- **OpenRouter model IDs** must be specific (e.g. `openrouter/deepseek/deepseek-v3.2`). Meta-routers like `openrouter/free` are NOT recognized by OpenClaw.
- **`agents.defaults.models`** per-model config keys like `timeoutSeconds` and `maxConcurrent` are no longer valid — OpenClaw rejects them as unrecognized keys and the gateway refuses to start. Remove the `models` block entirely.

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
- **Cloud-init user setup**: Terraform's `user_data` creates the `openclaw` user at boot. Ansible always connects as `openclaw` with `ansible_become=true` — no root SSH needed, even on first deploy.
- **Cloud-init race condition**: The common role runs `cloud-init status --wait` before any apt tasks. Without this, cloud-init's apt operations conflict with Ansible's, causing dpkg locks or network crashes.
- **Quick config updates**: For config-only changes, SSH + edit + `sudo systemctl restart openclaw-gateway` is faster than a full Ansible run. Use `--tags config,service` for Ansible-driven config updates.
- **Gateway management**: `sudo systemctl status|restart openclaw-gateway` and `sudo journalctl -u openclaw-gateway -f`.
- **Traefik** (https only): `sudo docker compose -f /opt/traefik/docker-compose.yml ps|logs|restart`.
- **Remote openclaw commands (one-off)**: `./scripts/openclaw-cmd.sh <subcommand> [args]` (use `-i` for interactive, e.g. WhatsApp login).
- **Remote openclaw commands (tunnel)**: `./scripts/openclaw-tunnel.sh start` then use `openclaw` locally (requires local install).
- **destroy.sh**: Use `./scripts/destroy.sh -y` or `--force` to skip the confirmation prompt for non-interactive use.

## Browser Tool + Web Search

- **Browser tool** (`enable_browser`): Installs Google Chrome + Playwright. Chrome runs headless with `--no-sandbox` (required under systemd `ProtectSystem=strict`). Config adds `browser` block to `openclaw.json` with `defaultProfile: "openclaw"` (managed mode — no Chrome extension needed). Chrome is pre-installed in Packer image; Playwright is always installed at deploy time to match OpenClaw version.
- **Brave Search** (`brave_api_key`): Terraform variable, flows via `terraform_vars.yml`. Sets `BRAVE_API_KEY` env var in gateway and adds `tools.web.search` to `openclaw.json`.
- Chrome adds ~500MB disk. `enable_browser: false` by default.
- **Browser profiles**: `openclaw` (managed headless, no extension) vs `chrome` (extension relay for personal browser). Server deployments must use `openclaw` profile.
- **systemd ReadWritePaths**: When `enable_browser` is true, the service template adds `/home/openclaw/.config` to `ReadWritePaths` — Chrome needs write access for its user data directory.
- **Chrome apt source conflict**: Chrome's deb package post-install script overwrites `/etc/apt/sources.list.d/google-chrome.list` without `signed-by`, conflicting with `apt_repository` module. The Ansible task uses `copy` instead of `apt_repository` and re-writes the file after install to restore `signed-by`.
- **Model capability**: The browser tool requires a model that supports tool use (e.g., Claude, GPT-4o). Free/small models may not invoke it correctly.
- **Docs**: https://docs.openclaw.ai/tools/browser.md, https://docs.openclaw.ai/tools/browser-linux-troubleshooting.md

## Telegram Bot

- Pairing flow: user sends `/start` to bot, receives a pairing code, then approve on server: `openclaw pairing approve telegram <CODE>`.
- DM policy `pairing` requires explicit approval per user.
