# Media Server

Docker-based media server stack running on Ubuntu.

## Services

| Service | Port | Description |
|---------|------|-------------|
| **Jellyfin** | 8096 | Media streaming server |
| **Jellyseerr** | 5055 | Media request management |
| **Sonarr** | 8989 | TV series management |
| **Radarr** | 7878 | Movie management |
| **Lidarr** | 8686 | Music management |
| **Bazarr** | 6767 | Subtitle management |
| **Prowlarr** | 9696 | Indexer management |
| **qBittorrent** | 8080 | Torrent client (host network) |
| **FlareSolverr** | 8191 | CloudFlare bypass proxy |
| **Traefik** | 80/8280 | Reverse proxy + dashboard |
| **Homepage** | 3000 | Dashboard |
| **Home Assistant** | 8123 | Smart home (host network) |
| **Watchtower** | — | Auto-update containers |
| **Unpackerr** | — | Auto-extract downloads |
| **Recyclarr** | — | TRaSH quality profile sync |
| **Notifiarr** | 5454 | Push notifications |

## Setup

1. Clone this repo to your home directory
2. Copy/restore config directories for each service
3. Create media mount at `/mnt/media/` with subdirs: Movies, Series, Anime, Animations, Music
4. `docker compose up -d`

## Traefik Routes

Services are accessible via `*.homelab.local` hostnames when DNS/hosts file is configured.

## Backup & Migration

### Config Data
Each service stores config in `./servicename/config/`. These are gitignored (contain API keys & databases) but must be backed up separately.

Key directories to back up:
- `jellyfin/config/` (~6GB) — libraries, users, metadata, databases
- `sonarr/config/`, `radarr/config/`, `lidarr/config/` — series/movie databases
- `prowlarr/config/` — indexer configs
- `bazarr/config/` — subtitle settings
- `qbittorrent/config/` — torrent state
- `homeassistant/config/` — HA integrations & automations

### Restoring on a New Machine

1. Clone this repo
2. Restore config directories from backup
3. Create media mount at `/mnt/media/` with subdirs
4. Create user/group matching PUID/PGID (122/124) or update in compose
5. `docker compose up -d`

### ⚠️ Jellyfin LinuxServer Image Path Quirk

The LinuxServer Jellyfin image sets `JELLYFIN_DATA_DIR=/config/data`, and Jellyfin creates an internal `data/` subdirectory under that. So the database lives at:

```
./jellyfin/config/data/data/jellyfin.db   (Docker/LinuxServer)
```

If migrating from a **native Jellyfin install** (where data dir was `/var/lib/jellyfin`), the DB will be at `./jellyfin/config/data/jellyfin.db` — one level too high. Copy it into `data/data/` to fix.

## Notes

- qBittorrent and Home Assistant use `network_mode: host` for LAN device discovery/UPnP
- All services run as PUID=122 PGID=124
- Watchtower auto-updates at 4am daily
- Config directories are gitignored (contain API keys)
- DNS fix: `/etc/systemd/resolved.conf.d/fallback-dns.conf` with Google/Cloudflare DNS for reliable Docker pulls
- Docker daemon config: `/etc/docker/daemon.json` with DNS `[8.8.8.8, 8.8.4.4, 1.1.1.1]` for container DNS
