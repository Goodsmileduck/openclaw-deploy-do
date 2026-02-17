#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== OpenClaw DigitalOcean Destroy ==="
echo ""

if [[ "${1:-}" != "-y" && "${1:-}" != "--force" ]]; then
  read -rp "This will destroy all OpenClaw infrastructure. Are you sure? (y/N) " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

cd "$ROOT_DIR/terraform"

# Detach the backup bucket from state so it's preserved after destroy.
# The bucket (and its backup data) remains in DO Spaces.
if terraform state list 2>/dev/null | grep -q 'digitalocean_spaces_bucket\.openclaw_backup'; then
  echo "Detaching backup bucket from Terraform state (bucket will be preserved)..."
  terraform state rm 'digitalocean_spaces_bucket.openclaw_backup[0]'
fi

terraform destroy -auto-approve

# Clean up generated Ansible files (safety net — Terraform should remove these)
rm -f "$ROOT_DIR/ansible/inventory.ini"
rm -f "$ROOT_DIR/ansible/terraform_vars.yml"

echo ""
echo "=== All resources destroyed ==="
