#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
RELEASE=$(lsb_release -cs)

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${RELEASE}.noarmor.gpg" \
  -o /etc/apt/keyrings/tailscale.gpg
chmod a+r /etc/apt/keyrings/tailscale.gpg

echo "deb [signed-by=/etc/apt/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu ${RELEASE} main" \
  > /etc/apt/sources.list.d/tailscale.list

apt-get update
apt-get install -y tailscale
systemctl enable tailscaled

apt-get install -y restic

echo "=== extras-setup.sh complete ==="
