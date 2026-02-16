#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-i] <subcommand> [args...]

Run openclaw CLI commands on the remote server via SSH.

Options:
  -i    Allocate TTY for interactive commands (e.g., channels login)

Examples:
  $(basename "$0") doctor
  $(basename "$0") pairing approve telegram 8Z6AMGWH
  $(basename "$0") channels status --probe
  $(basename "$0") -i channels login --channel whatsapp
EOF
  exit 1
}

# Parse -i flag
INTERACTIVE=false
if [[ "${1:-}" == "-i" ]]; then
  INTERACTIVE=true
  shift
fi

if [[ $# -eq 0 ]]; then
  usage
fi

# Extract connection details from Terraform state
cd "$ROOT_DIR/terraform"

if ! terraform output -raw droplet_ip &>/dev/null; then
  echo "Error: No Terraform state found. Run ./scripts/deploy.sh first." >&2
  exit 1
fi

DROPLET_IP=$(terraform output -raw droplet_ip)
SSH_PRIV_KEY=$(terraform output -raw ssh_private_key_path)

SSH_OPTS=(
  -i "$SSH_PRIV_KEY"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
)

if [[ "$INTERACTIVE" == true ]]; then
  SSH_OPTS+=(-t)
fi

exec ssh "${SSH_OPTS[@]}" "openclaw@${DROPLET_IP}" \
  "PATH=/home/openclaw/.local/bin:\$PATH openclaw $*"
