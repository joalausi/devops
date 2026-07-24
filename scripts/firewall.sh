#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-}"

log() {
  echo "==> [firewall] $*"
}

if [ -z "$ROLE" ]; then
  echo "Usage: firewall.sh <lb|web|app>"
  exit 1
fi

log "Configuring UFW for role: ${ROLE}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ufw

log "Resetting UFW rules"
ufw --force reset

log "Setting default policies"
ufw default deny incoming
ufw default allow outgoing

log "Allowing SSH"
ufw allow OpenSSH

case "$ROLE" in
  lb)
    log "Allowing HTTP/HTTPS to load balancer"
    ufw allow 80/tcp
    # ufw allow 443/tcp
    ;;

  web)
    log "Allowing HTTP only from lb-01"
    ufw allow from 192.168.56.10 to any port 80 proto tcp
    ;;

  app)
    log "Allowing backend API only from web-01 and web-02"
    ufw allow from 192.168.56.11 to any port 3000 proto tcp
    ufw allow from 192.168.56.12 to any port 3000 proto tcp
    ;;

  *)
    echo "Unknown role: ${ROLE}"
    exit 1
    ;;
esac

log "Enabling UFW"
ufw --force enable

log "UFW status"
ufw status verbose

log "Firewall provisioning completed for role: ${ROLE}"