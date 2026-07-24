#!/bin/sh
set -eu

cat > /usr/share/nginx/html/server-info.json <<EOF
{
  "web_server": "${WEB_SERVER_NAME:-unknown}",
  "generated_at": "$(date -Iseconds)"
}
EOF