#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME="${1:-$(hostname)}"

log() {
  echo "==> [web] $*"
}

export DEBIAN_FRONTEND=noninteractive

log "Installing Nginx on ${SERVER_NAME}"
apt-get update -y
apt-get install -y nginx

log "Creating web page for ${SERVER_NAME}"
cat >/var/www/html/index.html <<EOF
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>${SERVER_NAME}</title>
  </head>
  <body>
    <h1>Hello from ${SERVER_NAME}</h1>
    <p>This page is served by ${SERVER_NAME}.</p>
    <p>Role: Web Server</p>
  </body>
</html>
EOF

cat >/var/www/html/health <<EOF
ok ${SERVER_NAME}
EOF

chown -R www-data:www-data /var/www/html
chmod 644 /var/www/html/index.html /var/www/html/health

log "Enabling and starting Nginx"
systemctl enable --now nginx

log "Testing Nginx configuration"
nginx -t

log "Reloading Nginx"
systemctl reload nginx

log "Web provisioning completed for ${SERVER_NAME}"