# Storage and permissions

## Host-to-container paths

The same media root is exposed to each application through purpose-specific container paths:

| Host path | Container path | Used by |
|---|---|---|
| `${MEDIA_DIR}` | `/media` | Jellyfin |
| `${MEDIA_DIR}/Series` | `/tv` | Sonarr, Bazarr |
| `${MEDIA_DIR}/Anime` | `/anime` | Sonarr |
| `${MEDIA_DIR}/Movies` | `/movies` | Radarr, Bazarr |
| `${MEDIA_DIR}/Music` | `/music` | Lidarr |
| `${DOWNLOADS_DIR}` | `/downloads` | qBittorrent and Arr apps |

Keeping `/downloads` identical in qBittorrent and the Arr apps avoids remote path mappings.

## Choosing locations

The default `.env` created by `start.sh` uses repository-local folders. For an existing disk, NAS mount, or larger application-data volume, change the host paths:

```dotenv
CONFIG_DIR=/srv/media-server/config
MEDIA_DIR=/mnt/media
DOWNLOADS_DIR=/mnt/downloads
```

On macOS, a mounted external drive will usually be under `/Volumes`. On Linux it is commonly under `/mnt`, `/media`, or `/srv`. Make sure the drive is mounted before starting the stack.

## Permissions

LinuxServer containers use `PUID` and `PGID` from `.env`. Find the current values with:

```bash
id -u
id -g
```

The selected user must be able to read and write the media and download folders. On Linux, a typical new installation is:

```bash
sudo mkdir -p /mnt/media/{Movies,Series,Anime,Music} /mnt/downloads
sudo chown -R "$(id -u):$(id -g)" /mnt/media /mnt/downloads
```

Avoid changing ownership recursively on an established library until you understand its existing permissions.

## Moving storage later

1. Stop the stack with `docker compose --profile extras down`.
2. Copy the data while preserving permissions.
3. Change the matching path in `.env`.
4. Run `./start.sh --check`.
5. Start the stack and confirm the libraries and download paths before deleting the old copy.

The setup script preserves existing `.env` files and never moves or deletes media.
