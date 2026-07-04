#!/usr/bin/env bash
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

DEVICE="/dev/sda2"
EXPECTED_VOLUME="exfat ${DEVICE} uid=501,gid=20,umask=000"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'OK: %s\n' "$*"
}

docker info >/dev/null 2>&1 || fail "Docker is not ready"

if mount | grep -Fq ' on /Volumes/TOSHIBA EXT '; then
  fail "Toshiba is mounted by macOS at /Volumes/TOSHIBA EXT"
fi
info "macOS is not holding /Volumes/TOSHIBA EXT"

docker run --rm --privileged --pid=host --entrypoint sh alpine:latest \
  -lc "[ -b '${DEVICE}' ]" || fail "Docker host does not see ${DEVICE}"
info "Docker host sees ${DEVICE}"

volume_opts="$(docker volume inspect toshiba_ext --format '{{ index .Options "type" }} {{ index .Options "device" }} {{ index .Options "o" }}' 2>/dev/null || true)"
[[ "$volume_opts" == "$EXPECTED_VOLUME" ]] || fail "toshiba_ext options are '${volume_opts}', expected '${EXPECTED_VOLUME}'"
info "toshiba_ext points at ${DEVICE}"

if docker inspect --format '{{.State.Running}}' jellyfin 2>/dev/null | grep -qx true; then
  mount_line="$(docker exec jellyfin sh -lc 'mount | grep " /mnt/media "' 2>/dev/null || true)"
  [[ "$mount_line" != mac\ on\ /mnt/media\ type\ virtiofs* ]] || fail "Jellyfin is using macOS virtiofs"
  [[ "$mount_line" == "${DEVICE} on /mnt/media type exfat"* ]] || fail "unexpected Jellyfin mount: ${mount_line:-missing}"
  info "Jellyfin /mnt/media is direct exFAT: ${mount_line}"
else
  info "Jellyfin is not running; skipped container mount check"
fi
