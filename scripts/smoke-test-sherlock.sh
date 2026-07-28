#!/usr/bin/env bash
set -euo pipefail

MONITORING_URL="${MONITORING_URL:-http://192.168.56.15}"
APP_URL="${APP_URL:-http://192.168.56.13:3000}"

echo "==> Sherlock Logs smoke test"

check() {
  local name="$1"
  local url="$2"
  echo "[check] ${name}: ${url}"
  curl --fail --silent --show-error --max-time 15 "$url" >/dev/null
}

check "application Prometheus metrics" "${APP_URL}/prometheus"
check "Prometheus readiness" "${MONITORING_URL}:9090/-/ready"
check "Grafana health" "${MONITORING_URL}:3000/api/health"
check "Alertmanager readiness" "${MONITORING_URL}:9093/-/ready"
check "Kibana status" "${MONITORING_URL}:5601/api/status"

CLUSTER_JSON="$(curl --fail --silent --show-error "${MONITORING_URL}:9200/_cluster/health")"
python3 - "$CLUSTER_JSON" <<'PY'
import json
import sys

cluster = json.loads(sys.argv[1])
if cluster.get("status") != "green":
    raise SystemExit(f"Elasticsearch cluster is not green: {cluster.get('status')}")
if cluster.get("number_of_nodes", 0) < 2:
    raise SystemExit(f"Expected two Elasticsearch nodes, found {cluster.get('number_of_nodes', 0)}")
print(f"Elasticsearch cluster healthy: {cluster['number_of_nodes']} nodes, status={cluster['status']}")
PY

TARGETS_JSON="$(curl --fail --silent --show-error "${MONITORING_URL}:9090/api/v1/targets")"
python3 - "$TARGETS_JSON" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
active = payload["data"]["activeTargets"]
failed = [target for target in active if target.get("health") != "up"]
if failed:
    for target in failed:
        print("DOWN:", target.get("labels", {}).get("job"), target.get("scrapeUrl"), target.get("lastError"))
    raise SystemExit(1)
print(f"Prometheus targets healthy: {len(active)}")
PY

RULES_JSON="$(curl --fail --silent --show-error "${MONITORING_URL}:9090/api/v1/rules")"
python3 - "$RULES_JSON" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
rules = [rule for group in payload["data"]["groups"] for rule in group.get("rules", [])]
required = {
    "VMHighCPU",
    "VMLowDiskSpace",
    "VMHighMemory",
    "VMUnreachable",
    "ContainerRestartingFrequently",
    "ContainerHighMemory",
    "ElasticsearchClusterNotGreen",
}
found = {rule.get("name") for rule in rules}
missing = required - found
if missing:
    print("Missing mandatory alerts:", ", ".join(sorted(missing)))
    raise SystemExit(1)
print(f"Prometheus alert rules loaded: {len(rules)}")
PY

GRAFANA_RULES_JSON="$(curl --fail --silent --show-error \
  --user admin:sherlock \
  "${MONITORING_URL}:3000/api/v1/provisioning/alert-rules")"
python3 - "$GRAFANA_RULES_JSON" <<'PY'
import json
import sys

rules = json.loads(sys.argv[1])
required = {
    "grafana-vm-high-cpu",
    "grafana-vm-high-memory",
    "grafana-vm-low-disk",
}
found = {rule.get("uid") for rule in rules}
missing = required - found
if missing:
    raise SystemExit("Missing Grafana-managed alerts: " + ", ".join(sorted(missing)))
print(f"Grafana-managed alert rules loaded: {len(rules)}")
PY

for index in system-logs application-logs docker-logs; do
  echo "[check] Elasticsearch index family: ${index}-*"
  curl --fail --silent --show-error "${MONITORING_URL}:9200/_cat/indices/${index}-*?format=json" >/dev/null
 done

echo "Sherlock Logs smoke test passed."
