#!/usr/bin/env bash
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

MEDIA_SERVER_DIR="/Users/modestnerd/media-server"
DRIVE_PATH="/Volumes/TOSHIBA EXT"
LOG_DIR="${MEDIA_SERVER_DIR}/logs"
LOG_FILE="${LOG_DIR}/wait-for-toshiba-and-start.log"

mkdir -p "$LOG_DIR"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" | tee -a "$LOG_FILE"
}

is_drive_mounted() {
  mount | grep -Fq " on ${DRIVE_PATH} "
}

log "startup check beginning"

for attempt in $(seq 1 120); do
  if is_drive_mounted; then
    log "drive is mounted at ${DRIVE_PATH}"
    break
  fi

  if [[ "$attempt" -eq 120 ]]; then
    log "drive did not mount after 120 attempts"
    exit 75
  fi

  sleep 5
done

for attempt in $(seq 1 120); do
  if docker info >/dev/null 2>&1; then
    log "docker daemon is ready"
    break
  fi

  if [[ "$attempt" -eq 120 ]]; then
    log "docker daemon was not ready after 120 attempts"
    exit 75
  fi

  sleep 5
done

cd "$MEDIA_SERVER_DIR"
log "running docker compose up -d"
docker compose up -d >>"$LOG_FILE" 2>&1
log "startup check complete"
