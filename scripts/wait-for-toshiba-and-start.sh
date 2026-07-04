#!/usr/bin/env bash
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

MEDIA_SERVER_DIR="/Users/modestnerd/media-server"
USB_ID="00140000"
DEVICE="/dev/sda2"
DRIVE_PATH="/Volumes/TOSHIBA EXT"
LOG_DIR="${MEDIA_SERVER_DIR}/logs"
LOG_FILE="${LOG_DIR}/wait-for-toshiba-and-start.log"
MEDIA_SERVICES=(jellyfin sonarr radarr lidarr bazarr metube kompressor nexus)
COMPOSE=(docker compose --env-file "${MEDIA_SERVER_DIR}/.env" -f "${MEDIA_SERVER_DIR}/docker-compose.yml")

mkdir -p "$LOG_DIR"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" | tee -a "$LOG_FILE"
}

wait_for_docker() {
  for attempt in $(seq 1 120); do
    if docker info >/dev/null 2>&1; then
      log "docker daemon is ready"
      return 0
    fi

    sleep 5
  done

  log "docker daemon was not ready after 120 attempts"
  return 75
}

host_has_toshiba_partition() {
  docker run --rm --privileged --pid=host --entrypoint sh alpine:latest \
    -lc "[ -b '${DEVICE}' ]"
}

wait_for_toshiba_partition() {
  for attempt in $(seq 1 90); do
    if host_has_toshiba_partition; then
      log "docker host sees ${DEVICE}"
      return 0
    fi

    sleep 1
  done

  log "docker host did not expose ${DEVICE}"
  return 75
}

macos_has_drive_mounted() {
  mount | grep -Fq " on ${DRIVE_PATH} "
}

detach_from_macos() {
  if macos_has_drive_mounted; then
    log "unmounting macOS mount at ${DRIVE_PATH}"
    diskutil unmount "$DRIVE_PATH" >>"$LOG_FILE" 2>&1 || true
  fi
}

attach_to_orbstack() {
  if host_has_toshiba_partition; then
    return 0
  fi

  detach_from_macos
  log "attaching Toshiba USB ${USB_ID} to OrbStack"
  orbctl usb attach "$USB_ID" >>"$LOG_FILE" 2>&1 || true
  wait_for_toshiba_partition
}

volume_points_to_direct_device() {
  local opts
  opts="$(docker volume inspect toshiba_ext --format '{{ index .Options "type" }} {{ index .Options "device" }} {{ index .Options "o" }}' 2>/dev/null || true)"
  [[ "$opts" == "exfat ${DEVICE} uid=501,gid=20,umask=000" ]]
}

repair_volume_metadata_if_needed() {
  if volume_points_to_direct_device; then
    log "toshiba_ext already points at ${DEVICE}"
    return 0
  fi

  log "recreating stale toshiba_ext Docker volume metadata"
  "${COMPOSE[@]}" stop "${MEDIA_SERVICES[@]}" >>"$LOG_FILE" 2>&1 || true
  "${COMPOSE[@]}" rm -f "${MEDIA_SERVICES[@]}" >>"$LOG_FILE" 2>&1 || true
  docker volume rm toshiba_ext >>"$LOG_FILE" 2>&1 || true
}

start_stack() {
  log "running docker compose up -d for media services"
  "${COMPOSE[@]}" up -d "${MEDIA_SERVICES[@]}" >>"$LOG_FILE" 2>&1
}

verify_jellyfin_mount() {
  for attempt in $(seq 1 60); do
    if docker inspect --format '{{.State.Running}}' jellyfin 2>/dev/null | grep -qx true; then
      break
    fi
    sleep 1
  done

  local mount_line
  mount_line="$(docker exec jellyfin sh -lc 'mount | grep " /mnt/media "' 2>/dev/null || true)"
  log "jellyfin media mount: ${mount_line:-missing}"

  if [[ "$mount_line" == mac\ on\ /mnt/media\ type\ virtiofs* ]]; then
    log "bad mount detected: Jellyfin is using macOS virtiofs"
    return 75
  fi

  if [[ "$mount_line" != "${DEVICE} on /mnt/media type exfat"* ]]; then
    log "unexpected Jellyfin mount for /mnt/media"
    return 75
  fi
}

main() {
  cd "$MEDIA_SERVER_DIR"
  log "startup check beginning"
  wait_for_docker
  attach_to_orbstack
  repair_volume_metadata_if_needed
  start_stack
  verify_jellyfin_mount
  log "startup check complete"
}

main "$@"
