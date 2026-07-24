#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "==> [lb] $*"
}

export DEBIAN_FRONTEND=noninteractive

log "Installing Nginx on lb-01"
apt-get update -y
apt-get install -y nginx

log "Installing load balancer config"
cp /vagrant/configs/nginx-lb.conf /etc/nginx/sites-available/server-sorcery.conf

ln -sf /etc/nginx/sites-available/server-sorcery.conf /etc/nginx/sites-enabled/server-sorcery.conf

if [ -f /etc/nginx/sites-enabled/default ]; then
  rm /etc/nginx/sites-enabled/default
fi

log "Testing Nginx configuration"
nginx -t

log "Enabling and starting Nginx"
systemctl enable --now nginx

log "Reloading Nginx"
systemctl reload nginx

log "Load balancer provisioning completed"