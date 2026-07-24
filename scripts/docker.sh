#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "==> [docker] $*"
}

export DEBIAN_FRONTEND=noninteractive

log "Installing Docker dependencies"
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

log "Adding Docker official GPG key"
install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

chmod a+r /etc/apt/keyrings/docker.gpg

log "Adding Docker apt repository"
. /etc/os-release

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  >/etc/apt/sources.list.d/docker.list

log "Installing Docker Engine"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "Enabling Docker service"
systemctl enable --now docker

log "Adding devops and vagrant users to docker group"
usermod -aG docker devops || true
usermod -aG docker vagrant || true

log "Docker version"
docker --version

log "Docker provisioning completed"