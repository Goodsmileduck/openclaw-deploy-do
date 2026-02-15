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

# Ansible (installed in venv)
cd ansible && ansible-playbook playbook.yml --syntax-check
```

## Project Structure

```
terraform/          # Flat Terraform root module (no nested modules)
  versions.tf       # Terraform >= 1.14.0, DO provider ~> 2.40
  providers.tf      # DigitalOcean provider config
  variables.tf      # All input variables with defaults + validation
  main.tf           # Resources: droplet, firewall, SSH key, project, DNS
  outputs.tf        # Droplet IP, gateway URL, SSH command
  terraform.tfvars.example

ansible/            # Ansible with roles-based structure
  playbook.yml      # Main playbook — conditionally includes roles
  group_vars/all.yml # Default variable values
  inventory.ini.example
  roles/
    common/         # User, SSH hardening, UFW, fail2ban
    docker/         # Docker CE installation
    openclaw/       # Node.js, OpenClaw, systemd service
    nginx/          # Reverse proxy + Let's Encrypt (https only)
    tailscale/      # Mesh VPN (tailscale only)

scripts/
  deploy.sh         # Orchestrates terraform apply → ansible-playbook
  destroy.sh        # Tears down all infrastructure
```

## Key Conventions

- **Terraform:** Flat root module, no nested modules. All resources in `main.tf`.
- **Ansible:** Roles-based. Each role has `tasks/main.yml`, optional `handlers/main.yml` and `templates/`.
- **Templates:** Jinja2 (`.j2` extension) for Ansible templates.
- **Conditional roles:** nginx and tailscale roles are applied based on `access_method` variable.
- **Ubuntu 24.04:** SSH service is `ssh`, not `sshd`.

## Variable Flow

`terraform.tfvars` → Terraform outputs (droplet IP) → `scripts/deploy.sh` generates `ansible/inventory.ini` → Ansible reads `group_vars/all.yml` + `--extra-vars` for secrets.

## LLM Authentication

The `llm_api_key` is optional. Supported approaches:
- Pass API key at deploy: `--extra-vars "llm_api_key=..."`
- Use Claude setup-token post-deploy: `claude setup-token` then `openclaw models auth setup-token --provider anthropic`
- Supported providers: `anthropic`, `openai`, `openrouter`, `gemini`, `gradient`, `custom`
