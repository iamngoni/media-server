#!/bin/bash
# Jellyfin config backup script
# Keeps last 7 daily backups

BACKUP_DIR="/home/iamngoni/media-server/backups/jellyfin"
CONFIG_DIR="/home/iamngoni/jellyfin/config"
MAX_BACKUPS=7

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/jellyfin-config-$(date +%Y%m%d-%H%M%S).tar.gz"

# Backup critical files (skip cache/transcodes to save space)
tar -czf "$BACKUP_FILE" \
  -C "$CONFIG_DIR" \
  --exclude='cache' \
  --exclude='transcodes' \
  --exclude='metadata/*/images' \
  data \
  plugins \
  root \
  *.xml \
  *.json \
  2>/dev/null

# Get size
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "✓ Backup created: $BACKUP_FILE ($SIZE)"

# Cleanup old backups (keep last $MAX_BACKUPS)
cd "$BACKUP_DIR"
ls -t jellyfin-config-*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f

REMAINING=$(ls -1 jellyfin-config-*.tar.gz 2>/dev/null | wc -l)
echo "✓ Keeping $REMAINING backups"
