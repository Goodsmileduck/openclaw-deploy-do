#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Wait for cloud-init and any automatic apt processes to finish
echo "Waiting for apt locks to be released..."
cloud-init status --wait 2>/dev/null || true
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "  dpkg lock held, waiting 5s..."
  sleep 5
done

# Update and upgrade
apt-get update
apt-get dist-upgrade -y

# Base packages
apt-get install -y ufw fail2ban unattended-upgrades apt-transport-https ca-certificates curl gnupg

# Create openclaw user
useradd -m -s /bin/bash openclaw
usermod -aG sudo openclaw
echo "openclaw ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw
chmod 0440 /etc/sudoers.d/openclaw

# SSH hardening (matches Ansible common role blockinfile)
cat >> /etc/ssh/sshd_config <<'SSHEOF'
# BEGIN ANSIBLE MANAGED - SSH hardening
PermitRootLogin no
PasswordAuthentication no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowUsers openclaw
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
# END ANSIBLE MANAGED - SSH hardening
SSHEOF

# UFW
ufw default deny incoming
ufw default allow outgoing
ufw limit ssh
ufw --force enable

# fail2ban
cat > /etc/fail2ban/jail.local <<'F2BEOF'
[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 3
bantime = 86400
F2BEOF
systemctl enable fail2ban

# unattended-upgrades
dpkg --set-selections <<< "unattended-upgrades install"

echo "=== base-setup.sh complete ==="
