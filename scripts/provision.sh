#!/usr/bin/env bash
set -euo pipefail

INVENTORY="ansible/inventory.ini"

if [ -f .env ]; then
  echo "==> Loading environment from .env..."
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

echo "==> Syncing fresh Vagrant SSH keys..."
./scripts/sync-vagrant-keys.sh

echo "==> Checking if devops SSH access is already available..."

set +e
ansible all -i "$INVENTORY" -m ping -e ansible_user=devops >/tmp/automation-alchemy-devops-ping.log 2>&1
DEVOPS_PING_RC=$?
set -e

if [ "$DEVOPS_PING_RC" -ne 0 ]; then
  echo "==> devops SSH access is not ready yet."
  echo "==> Running bootstrap through temporary vagrant access..."

  ansible-playbook \
    -i "$INVENTORY" \
    ansible/bootstrap.yml \
    -e ansible_user=vagrant

  echo "==> Bootstrap finished."
else
  echo "==> devops SSH access already works. Skipping bootstrap."
fi

echo "==> Running full provisioning as devops..."

ansible-playbook \
  -i "$INVENTORY" \
  ansible/site.yml \
  -e ansible_user=devops

echo "==> Provisioning completed."
