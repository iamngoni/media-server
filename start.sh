#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
MODE="default"
CHECK_ONLY=false

usage() {
  cat <<'EOF'
Usage: ./start.sh [--core | --all] [--check]

Starts the portable media-server stack.

  (no option)  Core media services plus credential-free extras
  --core       Core media services only
  --all        Also enable automation services that need API keys/config
  --check      Prepare and validate configuration without starting containers
  -h, --help   Show this help
EOF
}

while (($#)); do
  case "$1" in
    --core)
      MODE="core"
      ;;
    --all)
      MODE="all"
      ;;
    --check)
      CHECK_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

detect_timezone() {
  if [[ -n "${TZ:-}" ]]; then
    printf '%s' "$TZ"
    return
  fi

  if [[ -L /etc/localtime ]]; then
    local zone
    zone="$(readlink /etc/localtime)"
    zone="${zone#*/zoneinfo/}"
    if [[ "$zone" != "$(readlink /etc/localtime)" ]]; then
      printf '%s' "$zone"
      return
    fi
  fi

  if command -v systemsetup >/dev/null 2>&1; then
    local zone
    zone="$(systemsetup -gettimezone 2>/dev/null | sed 's/^Time Zone: //')"
    if [[ -n "$zone" ]]; then
      printf '%s' "$zone"
      return
    fi
  fi

  printf 'Etc/UTC'
}

generate_app_key() {
  if command -v openssl >/dev/null 2>&1; then
    printf 'base64:%s' "$(openssl rand -base64 32 | tr -d '\n')"
  elif command -v base64 >/dev/null 2>&1 && [[ -r /dev/urandom ]]; then
    printf 'base64:%s' "$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d '\n')"
  else
    printf 'Could not generate SPEEDTEST_APP_KEY; install openssl or base64.\n' >&2
    return 1
  fi
}

write_env_file() {
  local timezone
  timezone="$(detect_timezone)"

  umask 077
  cat >"$ENV_FILE" <<EOF
COMPOSE_PROJECT_NAME=media-server
PUID=$(id -u)
PGID=$(id -g)
TZ=${timezone}
CONFIG_DIR=./data
MEDIA_DIR=./media
DOWNLOADS_DIR=./downloads
JELLYFIN_PORT=8096
SEERR_PORT=5055
QBITTORRENT_PORT=8080
TORRENT_PORT=6881
PROWLARR_PORT=9696
FLARESOLVERR_PORT=8191
SONARR_PORT=8989
RADARR_PORT=7878
LIDARR_PORT=8686
BAZARR_PORT=6767
METUBE_PORT=8081
JDOWNLOADER_PORT=5800
UPTIME_KUMA_PORT=3001
SPEEDTEST_PORT=8765
HOME_ASSISTANT_PORT=8123
NOTIFIARR_PORT=5454
SPEEDTEST_APP_KEY=$(generate_app_key)
SPEEDTEST_SCHEDULE=0 */6 * * *
UN_SONARR_API_KEY=
UN_RADARR_API_KEY=
UN_LIDARR_API_KEY=
NOTIFIARR_API_KEY=
EOF

  printf 'Created %s with local defaults.\n' "$ENV_FILE"
}

env_value() {
  local key="$1"
  local fallback="${2:-}"
  local value
  value="$(awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$ENV_FILE")"
  printf '%s' "${value:-$fallback}"
}

absolute_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    ./*) printf '%s/%s' "$ROOT_DIR" "${1#./}" ;;
    *) printf '%s/%s' "$ROOT_DIR" "$1" ;;
  esac
}

prepare_directories() {
  local config_dir media_dir downloads_dir
  config_dir="$(absolute_path "$(env_value CONFIG_DIR ./data)")"
  media_dir="$(absolute_path "$(env_value MEDIA_DIR ./media)")"
  downloads_dir="$(absolute_path "$(env_value DOWNLOADS_DIR ./downloads)")"

  mkdir -p "$config_dir" "$downloads_dir" \
    "$media_dir/Movies" "$media_dir/Series" "$media_dir/Anime" "$media_dir/Music"
}

require docker
docker compose version >/dev/null 2>&1 || {
  printf 'Docker Compose v2 is required (the command must be "docker compose").\n' >&2
  exit 1
}

cd "$ROOT_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  write_env_file
else
  printf 'Using existing %s (left unchanged).\n' "$ENV_FILE"
fi

prepare_directories

run_compose() {
  case "$MODE" in
    core)
      docker compose "$@"
      ;;
    default)
      docker compose --profile extras "$@"
      ;;
    all)
      docker compose --profile extras --profile automation "$@"
      ;;
  esac
}

run_compose config --quiet
printf 'Compose configuration is valid.\n'

if [[ "$CHECK_ONLY" == true ]]; then
  printf 'Check complete; no containers were started.\n'
  exit 0
fi

docker info >/dev/null 2>&1 || {
  printf 'Docker is installed but the daemon is not running. Start Docker and retry.\n' >&2
  exit 1
}

run_compose up -d --remove-orphans
run_compose ps

printf '\nMedia server started. Open http://localhost:%s for Jellyfin.\n' "$(env_value JELLYFIN_PORT 8096)"
printf 'Continue with the short first-run checklist in README.md.\n'
