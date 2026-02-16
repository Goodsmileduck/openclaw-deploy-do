#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="/tmp/openclaw-tunnel.pid"
LOCAL_PORT=18789
REMOTE_PORT=18789

usage() {
  cat <<EOF
Usage: $(basename "$0") [start|stop|status]

Manage an SSH tunnel to the remote OpenClaw gateway (port $LOCAL_PORT).
After starting, use openclaw commands locally (requires local openclaw install).

Commands:
  start   Start the tunnel in the background
  stop    Stop the tunnel
  status  Check if the tunnel is active

Examples:
  $(basename "$0") start
  openclaw doctor
  openclaw pairing approve telegram 8Z6AMGWH
  $(basename "$0") stop
EOF
  exit 1
}

get_connection_details() {
  cd "$ROOT_DIR/terraform"
  if ! terraform output -raw droplet_ip &>/dev/null; then
    echo "Error: No Terraform state found. Run ./scripts/deploy.sh first." >&2
    exit 1
  fi
  DROPLET_IP=$(terraform output -raw droplet_ip)
  SSH_PRIV_KEY=$(terraform output -raw ssh_private_key_path)
}

is_tunnel_alive() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(<"$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    rm -f "$PID_FILE"
  fi
  return 1
}

cmd_start() {
  if is_tunnel_alive; then
    echo "Tunnel already running (PID $(<"$PID_FILE"))."
    exit 0
  fi

  get_connection_details

  echo "Starting SSH tunnel: localhost:${LOCAL_PORT} -> ${DROPLET_IP}:${REMOTE_PORT}..."

  ssh -N -f \
    -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" \
    -i "$SSH_PRIV_KEY" \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o ExitOnForwardFailure=yes \
    "openclaw@${DROPLET_IP}"

  # Find the SSH process we just started
  local pid
  pid=$(pgrep -f "ssh.*-L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}.*openclaw@${DROPLET_IP}" | tail -1)

  if [[ -n "$pid" ]]; then
    echo "$pid" > "$PID_FILE"
    echo "Tunnel started (PID $pid)."
    echo "Gateway available at http://localhost:${LOCAL_PORT}"
    echo "Control UI at http://localhost:${LOCAL_PORT}/openclaw"
  else
    echo "Error: Tunnel process not found after starting." >&2
    exit 1
  fi
}

cmd_stop() {
  if ! is_tunnel_alive; then
    echo "No tunnel running."
    exit 0
  fi

  local pid
  pid=$(<"$PID_FILE")
  kill "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "Tunnel stopped (PID $pid)."
}

cmd_status() {
  if is_tunnel_alive; then
    local pid
    pid=$(<"$PID_FILE")
    echo "Tunnel running (PID $pid)."
    echo "Gateway at http://localhost:${LOCAL_PORT}"
  else
    echo "No tunnel running."
    exit 1
  fi
}

case "${1:-}" in
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  *)      usage ;;
esac
