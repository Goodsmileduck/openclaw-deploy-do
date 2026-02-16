#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  -o /etc/apt/keyrings/nodesource.asc
chmod a+r /etc/apt/keyrings/nodesource.asc

echo "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_22.x nodistro main" \
  > /etc/apt/sources.list.d/nodesource.list

apt-get update
apt-get install -y nodejs

npm install -g pnpm

mkdir -p /home/openclaw/.local/share/pnpm/global \
        /home/openclaw/.local/bin
chown -R openclaw:openclaw /home/openclaw/.local

su - openclaw -c "pnpm config set global-dir /home/openclaw/.local/share/pnpm/global"
su - openclaw -c "pnpm config set global-bin-dir /home/openclaw/.local/bin"

echo 'export PATH="/home/openclaw/.local/bin:$PATH"' >> /home/openclaw/.bashrc
chown openclaw:openclaw /home/openclaw/.bashrc

echo "=== nodejs-setup.sh complete ==="
