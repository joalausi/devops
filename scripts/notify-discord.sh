#!/usr/bin/env bash
set -euo pipefail

MESSAGE="${1:-Automation Alchemy notification}"

if [ -z "${DISCORD_REVIEW_WEBHOOK_URL:-}" ]; then
  echo "DISCORD_REVIEW_WEBHOOK_URL is not set. Skipping Discord notification."
  exit 0
fi

PAYLOAD_FILE="$(mktemp)"

cleanup() {
  rm -f "$PAYLOAD_FILE"
}
trap cleanup EXIT

python3 - "$MESSAGE" "$PAYLOAD_FILE" <<'PY'
import json
import sys

message = sys.argv[1]
payload_file = sys.argv[2]

payload = {
    "content": message[:1900],
    "allowed_mentions": {
        "parse": []
    }
}

with open(payload_file, "w", encoding="utf-8") as file:
    json.dump(payload, file, ensure_ascii=False)
PY

HTTP_CODE="$(
  curl -sS -o /tmp/discord-webhook-response.txt -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "User-Agent: Automation-Alchemy-CI/1.0" \
    -X POST \
    --data @"$PAYLOAD_FILE" \
    "$DISCORD_REVIEW_WEBHOOK_URL"
)"

if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "Discord notification sent. HTTP $HTTP_CODE"
  exit 0
fi

echo "Failed to send Discord notification. HTTP $HTTP_CODE"
cat /tmp/discord-webhook-response.txt || true
exit 0