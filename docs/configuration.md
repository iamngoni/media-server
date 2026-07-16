# Service configuration

Containers reach each other by Compose service name. Use the addresses below inside application settings; use `localhost` only from the host browser.

## 1. qBittorrent

Read the temporary password, sign in as `admin`, and immediately set a permanent password:

```bash
docker compose logs qbittorrent | grep -i 'temporary password'
```

Set the default save path to `/downloads`. Recommended categories:

| Category | Save path |
|---|---|
| `tv-sonarr` | `/downloads/tv` |
| `anime-sonarr` | `/downloads/anime` |
| `movies-radarr` | `/downloads/movies` |
| `music-lidarr` | `/downloads/music` |

## 2. Sonarr, Radarr, and Lidarr

Add qBittorrent as a download client in each app:

- Host: `qbittorrent`
- Port: `8080`
- Username and password: the permanent qBittorrent credentials
- Category: the matching category from the table above

Add root folders:

| App | Root folders |
|---|---|
| Sonarr | `/tv`, `/anime` |
| Radarr | `/movies` |
| Lidarr | `/music` |

Copy each app's API key from **Settings → General**. You will use it in Prowlarr and, optionally, the automation profile.

## 3. Prowlarr and FlareSolverr

Add FlareSolverr under **Settings → Indexers → Indexer Proxies**:

```text
http://flaresolverr:8191
```

After adding indexers, add the Arr apps under **Settings → Apps**:

| App | Address |
|---|---|
| Sonarr | `http://sonarr:8989` |
| Radarr | `http://radarr:7878` |
| Lidarr | `http://lidarr:8686` |

Use the matching API key for each app.

## 4. Bazarr

Configure its upstream apps with these internal addresses:

- Sonarr: host `sonarr`, port `8989`
- Radarr: host `radarr`, port `7878`

Use the API keys copied from those apps, then configure subtitle providers and language profiles.

## 5. Jellyfin and Seerr

In Jellyfin, add libraries using the container paths below:

- Movies: `/media/Movies`
- Series: `/media/Series`
- Anime: `/media/Anime`
- Music: `/media/Music`

In Seerr, sign in with a Jellyfin administrator and connect:

| Service | Internal address |
|---|---|
| Jellyfin | `http://jellyfin:8096` |
| Sonarr | `http://sonarr:8989` |
| Radarr | `http://radarr:7878` |

## Optional automation

Put the Arr keys and, if used, a Notifiarr key in `.env`:

```dotenv
UN_SONARR_API_KEY=...
UN_RADARR_API_KEY=...
UN_LIDARR_API_KEY=...
NOTIFIARR_API_KEY=...
```

Configure Recyclarr in `data/recyclarr/recyclarr.yml`, then start the automation profile:

```bash
./start.sh --all
```

Automation remains opt-in because these services need API keys or application-specific configuration.
