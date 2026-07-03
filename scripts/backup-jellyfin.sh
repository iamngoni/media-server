#!/bin/bash
set -euo pipefail

# Jellyfin config backup script — lean version
# Only backs up databases + config XML/JSON (skips metadata/images/thumbnails)
# Keeps last 7 daily backups

BACKUP_DIR="/Users/modestnerd/media-server/backups/jellyfin"
CONFIG_DIR="/Users/modestnerd/media-server/jellyfin/config"
MAX_BACKUPS=7

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/jellyfin-config-$(date +%Y%m%d-%H%M%S).tar.gz"

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "ERROR: Jellyfin config directory not found: $CONFIG_DIR" >&2
  exit 1
fi

# Backup only critical files:
# - Database files (jellyfin.db, etc.)
# - Config XML/JSON files
# - Plugins list
# - Scheduled tasks
# Skip: metadata (5.7GB images), data/metadata (2GB thumbnails)
(
  cd "$CONFIG_DIR"

  entries=()
  for path in \
    data/data \
    data/ScheduledTasks \
    data/collections \
    data/playlists \
    data/root \
    plugins; do
    [[ -e "$path" ]] && entries+=("$path")
  done

  for file in *.xml *.json; do
    [[ -e "$file" ]] && entries+=("$file")
  done

  if (( ${#entries[@]} == 0 )); then
    echo "ERROR: No Jellyfin config entries found to back up in $CONFIG_DIR" >&2
    exit 1
  fi

  tar -czf "$BACKUP_FILE" \
    --exclude='cache' \
    --exclude='transcodes' \
    --exclude='metadata' \
    --exclude='data/metadata' \
    --exclude='data/attachments' \
    --exclude='data/subtitles' \
    "${entries[@]}"
)

# Get size
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Backup created: $BACKUP_FILE ($SIZE)"

# Cleanup old backups (keep last $MAX_BACKUPS)
old_backups=()
while IFS= read -r backup; do
  old_backups+=("$backup")
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'jellyfin-config-*.tar.gz' -print | sort -r | tail -n +$((MAX_BACKUPS + 1)))
if (( ${#old_backups[@]} > 0 )); then
  rm -f "${old_backups[@]}"
fi

REMAINING=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'jellyfin-config-*.tar.gz' | wc -l | tr -d ' ')
echo "Keeping $REMAINING backups"
