#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "==> [final-hardening] $*"
}

log "Applying final SSH hardening: only devops can login"

cat >/etc/ssh/sshd_config.d/99-server-sorcery.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers devops
EOF

sshd -t

if systemctl list-unit-files | grep -q '^ssh.service'; then
  systemctl reload ssh
else
  systemctl reload sshd
fi

log "Removing passwordless sudo override if present"
rm -f /etc/sudoers.d/devops

log "Final hardening completed"