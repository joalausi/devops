#!/usr/bin/env bash
set -euo pipefail

KEY_DIR="$HOME/.ssh/automation-alchemy"

mkdir -p "$KEY_DIR"

for host in lb-01 web-01 web-02 app-01 ci-01 monitoring-01; do
  src=".vagrant/machines/$host/virtualbox/private_key"
  dst="$KEY_DIR/$host"

  if [ ! -f "$src" ]; then
    echo "Missing key for $host: $src"
    exit 1
  fi

  cp "$src" "$dst"
  chmod 600 "$dst"

  echo "Synced key for $host"
done

echo "All Vagrant SSH keys synced to $KEY_DIR"
