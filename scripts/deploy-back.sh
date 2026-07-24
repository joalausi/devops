#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="infrastructure-insight-backend"
CONTAINER_NAME="infrastructure-insight-backend"

cd /vagrant/backend

echo "==> Building backend image"
docker build -t "$IMAGE_NAME" .

echo "==> Removing old backend container if exists"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "==> Starting backend container"
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --network host \
  -e BACKEND_SERVER_NAME=app-01 \
  -e PORT=3000 \
  "$IMAGE_NAME"

echo "==> Backend container status"
docker ps --filter "name=$CONTAINER_NAME"

echo "==> Health check"
curl -s http://localhost:3000/health
echo