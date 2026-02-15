#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== OpenClaw DigitalOcean Deploy ==="
echo ""

# Step 1: Terraform
echo "[1/3] Provisioning infrastructure with Terraform..."
cd "$ROOT_DIR/terraform"

terraform init -input=false
terraform apply -auto-approve

DROPLET_IP=$(terraform output -raw droplet_ip)
echo "Droplet IP: $DROPLET_IP"

# Step 2: Generate Ansible inventory
echo ""
echo "[2/3] Generating Ansible inventory..."
cat > "$ROOT_DIR/ansible/inventory.ini" <<EOF
[openclaw]
openclaw-server ansible_host=${DROPLET_IP} ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

echo "Inventory written to ansible/inventory.ini"

# Step 3: Wait for SSH and run Ansible
echo ""
echo "[3/3] Waiting for SSH to become available..."
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$DROPLET_IP" true 2>/dev/null; then
    break
  fi
  echo "  Attempt $i/30 — waiting..."
  sleep 10
done

echo "Running Ansible playbook..."
cd "$ROOT_DIR/ansible"
ansible-playbook -i inventory.ini playbook.yml "$@"

echo ""
echo "=== Deploy complete! ==="
terraform -chdir="$ROOT_DIR/terraform" output
