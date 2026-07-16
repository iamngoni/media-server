#!/usr/bin/env bash
set -euo pipefail

zone_name="${ZONE_NAME:-antonlabs.cc}"
tailscale_ip="${TAILSCALE_IP:-100.122.121.82}"

private_hosts=(
  media
  jellyfin
  requests
  jellyseerr
  dash
  nexus
  deploy
  traefik
  sonarr
  radarr
  lidarr
  bazarr
  prowlarr
  status
  uptime
  speedtest
  kompressor
  metube
  jdownloader
  notifiarr
  qbit
  torrent
  home
  homeassistant
  flaresolverr
  openclaw
)

public_hosts=(
  heimdall
)

retired_tunnel_hosts=(
  '*'
)

require() {
  command -v "$1" >/dev/null || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

cf_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"

  if [[ -n "$data" ]]; then
    curl -fsS -X "$method" "https://api.cloudflare.com/client/v4$path" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$data"
  else
    curl -fsS -X "$method" "https://api.cloudflare.com/client/v4$path" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json"
  fi
}

upsert_record() {
  local type="$1"
  local name="$2"
  local content="$3"
  local proxied="$4"

  local fqdn="${name}.${zone_name}"
  local conflicting_ids
  conflicting_ids="$(cf_api GET "/zones/${zone_id}/dns_records?name=${fqdn}" | jq -r --arg type "$type" '.result[] | select(.type != $type) | .id')"
  local conflicting_id
  for conflicting_id in $conflicting_ids; do
    cf_api DELETE "/zones/${zone_id}/dns_records/${conflicting_id}" >/dev/null
  done

  local record_id
  record_id="$(cf_api GET "/zones/${zone_id}/dns_records?type=${type}&name=${fqdn}" | jq -r '.result[0].id // empty')"

  local payload
  payload="$(jq -n \
    --arg type "$type" \
    --arg name "$fqdn" \
    --arg content "$content" \
    --argjson proxied "$proxied" \
    '{type: $type, name: $name, content: $content, ttl: 1, proxied: $proxied}')"

  if [[ -n "$record_id" ]]; then
    cf_api PUT "/zones/${zone_id}/dns_records/${record_id}" "$payload" >/dev/null
    echo "updated ${type} ${fqdn} -> ${content}"
  else
    cf_api POST "/zones/${zone_id}/dns_records" "$payload" >/dev/null
    echo "created ${type} ${fqdn} -> ${content}"
  fi
}

delete_record() {
  local name="$1"
  local fqdn="${name}.${zone_name}"
  local record_ids
  record_ids="$(cf_api GET "/zones/${zone_id}/dns_records?name=${fqdn}" | jq -r '.result[].id')"
  local record_id
  for record_id in $record_ids; do
    cf_api DELETE "/zones/${zone_id}/dns_records/${record_id}" >/dev/null
    echo "deleted ${fqdn}"
  done
}

require curl
require jq

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  cert_file="${CLOUDFLARED_CERT:-${HOME}/.cloudflared/cert.pem}"
  if [[ -f "$cert_file" ]]; then
    CLOUDFLARE_API_TOKEN="$(
      python3 - "$cert_file" <<'PY'
import base64
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    body = "".join(line.strip() for line in f if not line.startswith("-----"))
padding = "=" * ((4 - len(body) % 4) % 4)
print(json.loads(base64.b64decode(body + padding))["apiToken"])
PY
    )"
    export CLOUDFLARE_API_TOKEN
  else
    echo "Set CLOUDFLARE_API_TOKEN with Zone:Read and DNS:Edit for ${zone_name}, or run cloudflared tunnel login first." >&2
    exit 1
  fi
fi

zone_id="$(cf_api GET "/zones?name=${zone_name}" | jq -r '.result[0].id // empty')"
if [[ -z "$zone_id" ]]; then
  echo "Could not find Cloudflare zone: ${zone_name}" >&2
  exit 1
fi

if ((${#private_hosts[@]})); then
  for host in "${private_hosts[@]}"; do
    upsert_record A "$host" "$tailscale_ip" false
  done
fi

if ((${#retired_tunnel_hosts[@]})); then
  for host in "${retired_tunnel_hosts[@]}"; do
    delete_record "$host"
  done
fi

if [[ -n "${CF_TUNNEL_UUID:-}" ]]; then
  tunnel_target="${CF_TUNNEL_UUID}.cfargotunnel.com"
  if ((${#public_hosts[@]})); then
    for host in "${public_hosts[@]}"; do
      upsert_record CNAME "$host" "$tunnel_target" true
    done
  fi
else
  echo "Skipped public tunnel CNAMEs; set CF_TUNNEL_UUID to add them."
fi
