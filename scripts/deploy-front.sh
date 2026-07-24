#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="infrastructure-insight-frontend"
CONTAINER_NAME="infrastructure-insight-frontend"
WEB_SERVER_NAME="$(hostname)"

cd /vagrant/frontend

echo "==> Building frontend image for ${WEB_SERVER_NAME}"
docker build -t "$IMAGE_NAME" .

echo "==> Stopping old host NGINX if it is running"
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

echo "==> Removing old frontend container if exists"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "==> Starting frontend container"
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --network host \
  --add-host app-01:192.168.56.13 \
  -e WEB_SERVER_NAME="$WEB_SERVER_NAME" \
  "$IMAGE_NAME"

echo "==> Frontend container status"
docker ps --filter "name=$CONTAINER_NAME"

echo "==> Local frontend check"
curl -s http://localhost/server-info.json
echo

echo "==> Backend proxy check"
curl -s http://localhost/api/metrics
echo