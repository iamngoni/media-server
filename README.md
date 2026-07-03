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
| **Kompressor** | 8078 | Local media transcoding queue |
| **Nexus** | 3000 | Homelab operations dashboard |

## Prerequisites

- Linux host with Docker + Docker Compose, or macOS with OrbStack/Docker Desktop
- Find your user/group IDs: `id $USER` → use the `uid` / `gid` for `PUID` / `PGID`
- Clone sibling repos for locally-built services:
  ```bash
  git clone https://github.com/iamngoni/kompressor.git ../kompressor
  git clone https://github.com/iamngoni/nexus.git ../nexus
  ```
- Create the media library structure (paths must match `MEDIA_DIR` in `.env`):
  ```bash
  sudo mkdir -p /mnt/media/{Movies,Series,Anime,Animations,Music}
  sudo chown -R $USER:$USER /mnt/media
  ```
- Create the downloads directory (matches `DOWNLOADS_DIR`):
  ```bash
  mkdir -p ~/downloads
  ```
- (Optional) Point `*.homelab.local` at the server, either in your router's DNS or on each client's `/etc/hosts`:
  ```
  192.168.1.x  jellyfin.homelab.local jellyseerr.homelab.local sonarr.homelab.local radarr.homelab.local lidarr.homelab.local bazarr.homelab.local prowlarr.homelab.local home.homelab.local notifiarr.homelab.local speedtest.homelab.local
  ```

## First-Time Bootstrap

```bash
cp .env.example .env
nano .env                # fill in PUID, PGID, paths, etc.
docker compose up -d
```

Then wire the services together in the order below — the Arr stack depends on qBittorrent and Prowlarr.

## Service Configuration

### 1. qBittorrent — `http://<server>:8080`

The linuxserver image generates a **temporary admin password on every restart** until you set a permanent one. Grab it from the logs:

```bash
docker logs qbittorrent 2>&1 | grep -i "temporary password"
```

Login as `admin` + that password, then:

1. **Settings → WebUI → Authentication** — set a permanent username and password (save before doing anything else).
2. **Settings → Downloads → Default Save Path** — set to `/downloads`.
3. (Recommended) Create categories so each Arr drops files in its own subfolder. In the left sidebar, right-click **Categories → Add Category**:
   - `tv-sonarr` → save path `/downloads/tv`
   - `movies-radarr` → `/downloads/movies`
   - `music-lidarr` → `/downloads/music`
   - `anime-sonarr` → `/downloads/anime`

#### ⚠️ Host-networking gotcha

qBittorrent runs with `network_mode: host`, so it is **not** reachable as `http://qbittorrent:8080` from the Arr containers (they're on Docker's bridge network, qBit isn't). Two options when adding qBit as a download client below:

- **Easiest**: use the host's LAN IP, e.g. `http://192.168.1.x:8080`
- **Portable**: add the following to each Arr service in `docker-compose.yml`, then use `http://host.docker.internal:8080`:
  ```yaml
  extra_hosts:
    - "host.docker.internal:host-gateway"
  ```

### 2. Prowlarr — `http://<server>:9696`

1. Set admin authentication on first launch.
2. **Settings → Indexers → Indexer Proxies → Add → FlareSolverr**
   - Host: `http://flaresolverr:8191`
3. **Indexers → Add Indexer** — add your trackers. For Cloudflare-protected ones, attach the FlareSolverr proxy tag.
4. **Settings → General** — copy the API key (you'll need it for Apps).
5. After Sonarr/Radarr/Lidarr are configured (steps 3–5), come back and **Settings → Apps → Add** each one:
   - Prowlarr URL (how the Arr reaches Prowlarr): `http://prowlarr:9696`
   - Sonarr URL: `http://sonarr:8989` — and the Sonarr API key
   - Radarr URL: `http://radarr:7878` — Radarr API key
   - Lidarr URL: `http://lidarr:8686` — Lidarr API key

### 3. Sonarr — `http://<server>:8989`

1. Set authentication.
2. **Settings → Media Management → Root Folders → Add** → `/tv` and `/anime`.
3. **Settings → Download Clients → Add → qBittorrent**
   - Host: host LAN IP or `host.docker.internal` (see gotcha above)
   - Port: `8080`
   - Username / Password: from step 1
   - Category: `tv-sonarr`
4. **Settings → General → Security** — copy the API key. Paste it into Prowlarr (step 2.5) and into `.env` as `UN_SONARR_API_KEY`.

### 4. Radarr — `http://<server>:7878`

Same as Sonarr, but:
- Root folder: `/movies`
- Download client category: `movies-radarr`
- API key → Prowlarr Apps + `.env` as `UN_RADARR_API_KEY`

### 5. Lidarr — `http://<server>:8686`

Same as Sonarr, but:
- Root folder: `/music`
- Download client category: `music-lidarr`
- API key → Prowlarr Apps + `.env` as `UN_LIDARR_API_KEY`

### 6. Bazarr — `http://<server>:6767`

1. **Settings → Sonarr** — Address `sonarr`, Port `8989`, API key. Test and save.
2. **Settings → Radarr** — Address `radarr`, Port `7878`, API key.
3. **Settings → Providers** — enable subtitle providers (OpenSubtitles, Subscene, etc.) and add your credentials.
4. **Settings → Languages** — define profiles and assign to your series/movies.

### 7. Unpackerr

After collecting all three Arr API keys, update `.env` and restart just unpackerr:

```bash
docker compose up -d unpackerr
```

### 8. Jellyfin — `http://<server>:8096`

1. Run the setup wizard.
2. Add libraries — paths inside the container match the host (volumes are mapped 1:1):
   - Movies → `/mnt/media/Movies`
   - Shows → `/mnt/media/Series` and `/mnt/media/Anime` (or a separate "Anime" library)
   - Music → `/mnt/media/Music`
3. (Optional) **Dashboard → Playback → Transcoding** — enable hardware transcoding only if the host runtime exposes compatible devices.

### 9. Jellyseerr — `http://<server>:5055`

1. Run the wizard and sign in with a Jellyfin admin account.
2. **Settings → Services → Radarr → Add Server**
   - Hostname: `radarr`, Port `7878`, API key
   - Default root folder and quality profile
3. Repeat for **Sonarr** (`sonarr:8989`) and, if using the music fork, **Lidarr** (`lidarr:8686`).

### 10. Recyclarr

Edit `recyclarr/config/recyclarr.yml` — add Sonarr/Radarr base URLs (`http://sonarr:8989`, `http://radarr:7878`), API keys, and pick the TRaSH profiles you want. Then trigger a sync:

```bash
docker compose run --rm recyclarr sync
```

The running container handles scheduled syncs after that.

### 11. Notifiarr (optional)

Sign up at [notifiarr.com](https://notifiarr.com), paste the API key into `.env` as `NOTIFIARR_API_KEY`, then `docker compose up -d notifiarr`. Configure integrations through the Notifiarr web UI.

### 12. Nexus — `http://<server>:3000`

Nexus replaces Homepage as the dashboard. It reads service URLs and API keys from `../nexus/.env` plus the `NEXUS_*` variables in this repo's `.env`.

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

Services are routed by Traefik on `antonlabs.cc` hostnames. Private media/admin apps should use DNS-only Cloudflare records pointing at the Mac mini's Tailscale IP (`100.122.121.82`), so they resolve from anywhere but only connect from devices on the tailnet.

Traefik serves HTTPS on port 443 and redirects HTTP to HTTPS. Certificates are issued with Let's Encrypt through the Cloudflare DNS challenge for `antonlabs.cc` and `*.antonlabs.cc`; the ignored local `.env` must provide `ACME_EMAIL` and `CLOUDFLARE_DNS_API_TOKEN`.

Private lane:

- `media.antonlabs.cc` / `jellyfin.antonlabs.cc` → Jellyfin
- `requests.antonlabs.cc` / `jellyseerr.antonlabs.cc` → Jellyseerr
- `dash.antonlabs.cc` / `nexus.antonlabs.cc` → Nexus
- `traefik.antonlabs.cc` → Traefik dashboard
- `sonarr.antonlabs.cc`, `radarr.antonlabs.cc`, `lidarr.antonlabs.cc`, `bazarr.antonlabs.cc`, `prowlarr.antonlabs.cc`
- `status.antonlabs.cc` / `uptime.antonlabs.cc` → Uptime Kuma
- `speedtest.antonlabs.cc`, `kompressor.antonlabs.cc`, `metube.antonlabs.cc`, `jdownloader.antonlabs.cc`, `notifiarr.antonlabs.cc`
- `openclaw.antonlabs.cc` → OpenClaw Control

Public lane:

- Run public apps through Cloudflare Tunnel. The compose file includes an optional `cloudflared` service behind the `public` profile:
  ```bash
  docker compose --profile public up -d cloudflared
  ```
- The local tunnel config lives in `cloudflared/config.yml`; secret tunnel credentials are stored as ignored `cloudflared/*.json` files.
- Configure public hostnames such as `heimdall.antonlabs.cc` to target Traefik, then add a matching Traefik router/service for the public app.

To sync Cloudflare DNS records for the private lane:

```bash
./scripts/sync-cloudflare-antonlabs.sh
```

If `CLOUDFLARE_API_TOKEN` is not set, the script will reuse the token from `~/.cloudflared/cert.pem` created by `cloudflared tunnel login`. If `CF_TUNNEL_UUID` is also set, the script will create the public `heimdall.antonlabs.cc` CNAME to the tunnel target. The same cert can be decoded to populate `CLOUDFLARE_DNS_API_TOKEN` in `.env` for Traefik's DNS challenge.

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
2. Clone `kompressor` and `nexus` next to this repo
3. Restore config directories from backup
4. Create the media mount and downloads dir, matching `MEDIA_DIR` / `DOWNLOADS_DIR` in `.env`
5. Copy `.env.example` → `.env` and fill in `PUID`, `PGID`, and the host paths to match the restored state
6. `docker compose up -d`

### ⚠️ Jellyfin LinuxServer Image Path Quirk

The LinuxServer Jellyfin image sets `JELLYFIN_DATA_DIR=/config/data`, and Jellyfin creates an internal `data/` subdirectory under that. So the database lives at:

```
./jellyfin/config/data/data/jellyfin.db   (Docker/LinuxServer)
```

If migrating from a **native Jellyfin install** (where data dir was `/var/lib/jellyfin`), the DB will be at `./jellyfin/config/data/jellyfin.db` — one level too high. Copy it into `data/data/` to fix.

## Notes

- qBittorrent and Home Assistant use `network_mode: host` for LAN device discovery/UPnP
- All services run as `PUID` / `PGID` from `.env`
- Watchtower auto-updates at 4am daily
- Config directories are gitignored (contain API keys)
- DNS fix: `/etc/systemd/resolved.conf.d/fallback-dns.conf` with Google/Cloudflare DNS for reliable Docker pulls
- Docker daemon config: `/etc/docker/daemon.json` with DNS `[8.8.8.8, 8.8.4.4, 1.1.1.1]` for container DNS
- MeTube downloads to `DOWNLOADS_DIR` — manually move files into `/mnt/media/...` (or whatever `MEDIA_DIR` is set to)
- Kompressor and Nexus are now part of the main compose file. The old separate/custom compose file is no longer needed.
- On macOS, set `MEDIA_DIR` to the external drive path under `/Volumes/...`.

## Seerr (Jellyseerr Fork with Music Support)

Running a local fork of [seerr-team/seerr](https://github.com/seerr-team/seerr) with [PR #2132](https://github.com/seerr-team/seerr/pull/2132) merged for Lidarr/music support.

- **Fork repo:** [iamngoni/seerr](https://github.com/iamngoni/seerr)
- **Image:** `seerr-music:latest` (built locally)
- **Build:** `cd ~/seerr-fork && sudo docker build --build-arg COMMIT_TAG=local -t seerr-music:latest .`
- **Config perms:** `sudo chown -R 1000:1000 ./jellyseerr/config`

When official Seerr merges music support, revert to `fallenbagel/jellyseerr:latest` in docker-compose.yml.
