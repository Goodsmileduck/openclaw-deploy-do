#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== OpenClaw DigitalOcean Destroy ==="
echo ""
read -rp "This will destroy all OpenClaw infrastructure. Are you sure? (y/N) " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

cd "$ROOT_DIR/terraform"
terraform destroy -auto-approve

# Clean up generated Ansible files (safety net — Terraform should remove these)
rm -f "$ROOT_DIR/ansible/inventory.ini"
rm -f "$ROOT_DIR/ansible/terraform_vars.yml"

echo ""
echo "=== All resources destroyed ==="
