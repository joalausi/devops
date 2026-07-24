#!/usr/bin/env bash
set -euo pipefail

LB_URL="${LB_URL:-http://192.168.56.10}"
BACKEND_URL="${BACKEND_URL:-http://192.168.56.13:3000}"
WEB_01_URL="${WEB_01_URL:-http://192.168.56.11:8080}"
WEB_02_URL="${WEB_02_URL:-http://192.168.56.12:8080}"

echo "==> Automation Alchemy healthcheck"
echo

echo "[1/6] Checking backend health..."
curl -fsS "${BACKEND_URL}/health"
echo
echo

echo "[2/6] Checking backend metrics..."
curl -fsS "${BACKEND_URL}/metrics" > /dev/null
echo "Backend metrics endpoint is reachable."
echo

echo "[3/6] Checking web-01 frontend API proxy..."
curl -fsS "${WEB_01_URL}/api/health"
echo
echo

echo "[4/6] Checking web-02 frontend API proxy..."
curl -fsS "${WEB_02_URL}/api/health"
echo
echo

echo "[5/6] Checking load balancer API proxy..."
curl -fsS "${LB_URL}/api/health"
echo
echo

echo "[6/6] Checking load balancer frontend page..."
curl -fsS "${LB_URL}" > /dev/null
echo "Load balancer frontend endpoint is reachable."
echo

echo "Healthcheck passed."