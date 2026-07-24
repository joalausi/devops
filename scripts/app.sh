#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "==> [app] $*"
}

export DEBIAN_FRONTEND=noninteractive

log "Installing Nginx on app-01"
apt-get update -y
apt-get install -y nginx

log "Creating diagnostic app page"
cat >/var/www/html/index.html <<EOF
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>app-01</title>
  </head>
  <body>
    <h1>Application server is running</h1>
    <p>Hostname: app-01</p>
    <p>IP: 192.168.56.13</p>
    <p>Role: Application Server</p>
  </body>
</html>
EOF

cat >/var/www/html/health <<EOF
ok app-01
EOF

chown -R www-data:www-data /var/www/html
chmod 644 /var/www/html/index.html /var/www/html/health

log "Enabling and starting Nginx"
systemctl enable --now nginx

log "Testing Nginx configuration"
nginx -t

log "Reloading Nginx"
systemctl reload nginx

log "App provisioning completed"