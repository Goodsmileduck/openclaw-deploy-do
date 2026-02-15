#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Activate Ansible venv if ansible-playbook is not in PATH
if ! command -v ansible-playbook &>/dev/null; then
  if [ -f "$HOME/.ansible-venv/bin/activate" ]; then
    source "$HOME/.ansible-venv/bin/activate"
  else
    echo "Error: ansible-playbook not found. Install Ansible or create venv at ~/.ansible-venv" >&2
    exit 1
  fi
fi

echo "=== OpenClaw DigitalOcean Deploy ==="
echo ""

# Step 1: Terraform
echo "[1/3] Provisioning infrastructure with Terraform..."
cd "$ROOT_DIR/terraform"

terraform init -input=false
terraform apply -auto-approve

DROPLET_IP=$(terraform output -raw droplet_ip)
echo "Droplet IP: $DROPLET_IP"

# Read outputs from Terraform to pass through to Ansible
REGION=$(terraform output -raw region 2>/dev/null || echo "nyc3")
CLAUDE_TOKEN=$(terraform output -raw claude_setup_token 2>/dev/null || true)
TELEGRAM_TOKEN=$(terraform output -raw telegram_bot_token 2>/dev/null || true)

EXTRA_VARS="region=$REGION"
[ -n "$CLAUDE_TOKEN" ] && EXTRA_VARS="$EXTRA_VARS claude_setup_token=$CLAUDE_TOKEN"
[ -n "$TELEGRAM_TOKEN" ] && EXTRA_VARS="$EXTRA_VARS telegram_bot_token=$TELEGRAM_TOKEN"

# Step 2: Generate Ansible inventory
echo ""
echo "[2/3] Generating Ansible inventory..."
SSH_PUB_KEY=$(terraform output -raw ssh_public_key_path 2>/dev/null || echo "~/.ssh/id_do_ssh.pub")
SSH_PUB_KEY="${SSH_PUB_KEY/#\~/$HOME}"
SSH_PRIV_KEY="${SSH_PUB_KEY%.pub}"
cat > "$ROOT_DIR/ansible/inventory.ini" <<EOF
[openclaw]
openclaw-server ansible_host=${DROPLET_IP} ansible_user=root ansible_ssh_private_key_file=${SSH_PRIV_KEY}
EOF

echo "Inventory written to ansible/inventory.ini"

# Step 3: Wait for SSH and run Ansible
echo ""
echo "[3/3] Waiting for SSH to become available..."
for i in $(seq 1 30); do
  if ssh -i "$SSH_PRIV_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$DROPLET_IP" true 2>/dev/null; then
    break
  fi
  echo "  Attempt $i/30 — waiting..."
  sleep 10
done

echo "Running Ansible playbook..."
cd "$ROOT_DIR/ansible"
ansible-playbook -i inventory.ini playbook.yml \
  ${EXTRA_VARS:+--extra-vars "$EXTRA_VARS"} "$@"

echo ""
echo "=== Deploy complete! ==="
terraform -chdir="$ROOT_DIR/terraform" output
