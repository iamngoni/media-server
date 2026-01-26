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

## Notes

- qBittorrent and Home Assistant use `network_mode: host` for LAN device discovery/UPnP
- All services run as PUID=122 PGID=124
- Watchtower auto-updates at 4am daily
- Config directories are gitignored (contain API keys)
