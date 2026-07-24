#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "==> [common] $*"
}

export DEBIAN_FRONTEND=noninteractive

DEVOPS_PASSWORD="${DEVOPS_PASSWORD:-DevOps123!}"

log "Updating package index"
apt-get update -y

log "Upgrading installed packages"
apt-get upgrade -y
apt-get autoremove -y

log "Installing base packages"
apt-get install -y \
  curl \
  vim \
  ufw \
  unattended-upgrades \
  openssh-server

log "Configuring hostname resolution"
sed -i '/# Server Sorcery hosts start/,/# Server Sorcery hosts end/d' /etc/hosts

cat >>/etc/hosts <<'EOF'
# Server Sorcery hosts start
192.168.56.10 lb-01
192.168.56.11 web-01
192.168.56.12 web-02
192.168.56.13 app-01
# Server Sorcery hosts end
EOF

log "Creating devops user if missing"
if ! id -u devops >/dev/null 2>&1; then
  useradd -m -s /bin/bash devops
fi

log "Setting password for devops user"
echo "devops:${DEVOPS_PASSWORD}" | chpasswd

log "Adding devops user to sudo group"
usermod -aG sudo devops

log "Ensuring devops sudo is password-protected"
rm -f /etc/sudoers.d/devops

log "Configuring SSH authorized key for devops"
mkdir -p /home/devops/.ssh

if [ -f /vagrant/.ssh/devops_key.pub ]; then
  cp /vagrant/.ssh/devops_key.pub /home/devops/.ssh/authorized_keys
elif [ -f /home/vagrant/.ssh/authorized_keys ]; then
  cp /home/vagrant/.ssh/authorized_keys /home/devops/.ssh/authorized_keys
fi

chown -R devops:devops /home/devops/.ssh
chmod 700 /home/devops/.ssh

if [ -f /home/devops/.ssh/authorized_keys ]; then
  chmod 600 /home/devops/.ssh/authorized_keys
fi

log "Applying SSH hardening for provisioning stage"
cat >/etc/ssh/sshd_config.d/99-server-sorcery.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers devops vagrant
EOF

sshd -t

if systemctl list-unit-files | grep -q '^ssh.service'; then
  systemctl reload ssh
else
  systemctl reload sshd
fi

log "Configuring secure umask"
cat >/etc/profile.d/99-secure-umask.sh <<'EOF'
# Server Sorcery 101 secure default permissions
umask 027
EOF

chmod 644 /etc/profile.d/99-secure-umask.sh

if grep -q '^UMASK' /etc/login.defs; then
  sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs
else
  echo 'UMASK 027' >> /etc/login.defs
fi

log "Enabling automatic security updates"
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable --now unattended-upgrades

log "Common provisioning completed"