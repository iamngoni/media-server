# Media Server

Docker-based media server stack running on Ubuntu.

## Services

| Service | Port | Description |
|---------|------|-------------|
| **Jellyfin** | 8096 | Media streaming server |
| **Seerr** | 5055 | Media request management (local fork with music/Lidarr support) |
| **Sonarr** | 8989 | TV series management |
| **Radarr** | 7878 | Movie management |
| **Lidarr** | 8686 | Music management |
| **Bazarr** | 6767 | Subtitle management |
| **Prowlarr** | 9696 | Indexer management |
| **qBittorrent** | 8080 | Torrent client (host network) |
| **MeTube** | 8081 | YouTube downloader (yt-dlp web UI) |
| **FlareSolverr** | 8191 | CloudFlare bypass proxy |
| **Traefik** | 80/8280 | Reverse proxy + dashboard |
| **Speedtest Tracker** | 8765 | Periodic speed tests |
| **Home Assistant** | 8123 | Smart home (host network) |
| **Watchtower** | — | Auto-update containers |
| **Unpackerr** | — | Auto-extract downloads |
| **Recyclarr** | — | TRaSH quality profile sync |
| **Notifiarr** | 5454 | Push notifications |

## Setup

1. Clone this repo to your home directory
2. Copy `.env.example` to `.env` and fill in your values:
   ```bash
   cp .env.example .env
   nano .env
   ```
3. Copy/restore config directories for each service
4. Create media mount at `/mnt/media/` with subdirs: Movies, Series, Anime, Animations, Music
5. `docker compose up -d`

## Environment Variables

Sensitive keys are stored in `.env` (gitignored). See `.env.example` for required variables:

| Variable | Service | Description |
|----------|---------|-------------|
| `PUID` / `PGID` | All | User/Group ID for file permissions |
| `TZ` | All | Timezone |
| `UN_SONARR_API_KEY` | Unpackerr | Sonarr API key |
| `UN_RADARR_API_KEY` | Unpackerr | Radarr API key |
| `UN_LIDARR_API_KEY` | Unpackerr | Lidarr API key |
| `NOTIFIARR_API_KEY` | Notifiarr | Notifiarr API key |
| `SPEEDTEST_APP_KEY` | Speedtest | Laravel app key (generate with `openssl rand -base64 32`) |

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
- MeTube downloads to `/home/iamngoni/downloads` — manually move files to appropriate media folders

## Seerr (Jellyseerr Fork with Music Support)

Running a local fork of [seerr-team/seerr](https://github.com/seerr-team/seerr) with [PR #2132](https://github.com/seerr-team/seerr/pull/2132) merged for Lidarr/music support.

- **Fork repo:** [iamngoni/seerr](https://github.com/iamngoni/seerr)
- **Image:** `seerr-music:latest` (built locally)
- **Build:** `cd ~/seerr-fork && sudo docker build --build-arg COMMIT_TAG=local -t seerr-music:latest .`
- **Config perms:** `sudo chown -R 1000:1000 ./jellyseerr/config`

When official Seerr merges music support, revert to `fallenbagel/jellyseerr:latest` in docker-compose.yml.
