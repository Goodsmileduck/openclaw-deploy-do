#!/usr/bin/env bash
set -euo pipefail

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

find /var/log -type f -name '*.log' -exec truncate -s 0 {} \;
truncate -s 0 /var/log/lastlog
truncate -s 0 /var/log/wtmp

rm -rf /tmp/* /var/tmp/*

unset HISTFILE
rm -f /root/.bash_history /home/openclaw/.bash_history

dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo "=== cleanup.sh complete ==="
