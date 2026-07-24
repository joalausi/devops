#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "==> [fail2ban] $*"
}

export DEBIAN_FRONTEND=noninteractive

log "Installing Fail2Ban"
apt-get update -y
apt-get install -y fail2ban python3-systemd

log "Configuring SSH jail"
cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
backend = systemd
EOF

log "Testing Fail2Ban configuration"
fail2ban-client -t

log "Enabling and restarting Fail2Ban"
systemctl enable fail2ban
systemctl restart fail2ban

log "Waiting for Fail2Ban socket"
for i in {1..10}; do
  if fail2ban-client ping >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

log "Fail2Ban status"
fail2ban-client status
fail2ban-client status sshd

log "Fail2Ban provisioning completed"