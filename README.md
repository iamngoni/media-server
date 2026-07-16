# Media Server

A portable Docker Compose stack for Jellyfin, Seerr, the Arr apps, download clients, and a few useful homelab extras. It uses ordinary host paths, has no required domain name, and works on Linux or macOS with Docker Compose v2.

## Quick start

Install Docker, then run:

```bash
git clone https://github.com/iamngoni/media-server.git
cd media-server
./start.sh
```

That one command:

- creates a private `.env` with your user IDs and timezone when needed;
- creates local config, download, and media folders;
- validates the Compose configuration;
- starts the complete stack that does not require third-party API keys.

Existing `.env` files are never overwritten.

## Open the apps

| App | URL | Purpose |
|---|---|---|
| Jellyfin | <http://localhost:8096> | Stream media |
| Seerr | <http://localhost:5055> | Request movies and series |
| qBittorrent | <http://localhost:8080> | Download client |
| Sonarr | <http://localhost:8989> | Series management |
| Radarr | <http://localhost:7878> | Movie management |
| Lidarr | <http://localhost:8686> | Music management |
| Bazarr | <http://localhost:6767> | Subtitle management |
| Prowlarr | <http://localhost:9696> | Indexer management |
| MeTube | <http://localhost:8081> | Video downloader |
| JDownloader | <http://localhost:5800> | General downloader |
| Uptime Kuma | <http://localhost:3001> | Service monitoring |
| Speedtest Tracker | <http://localhost:8765> | Network measurements |
| Home Assistant | <http://localhost:8123> | Home automation |

If you changed a port in `.env`, use that port instead.

## First-run checklist

1. Open qBittorrent and set a permanent password. Its temporary password is shown by:

   ```bash
   docker compose logs qbittorrent | grep -i 'temporary password'
   ```

2. Add qBittorrent to Sonarr, Radarr, and Lidarr with host `qbittorrent`, port `8080`, and download path `/downloads`.
3. Add these root folders: Sonarr `/tv` and `/anime`, Radarr `/movies`, Lidarr `/music`.
4. Add FlareSolverr to Prowlarr as `http://flaresolverr:8191`, then connect Prowlarr to the Arr apps using their service names.
5. Connect Seerr to Jellyfin, Sonarr, and Radarr.

The exact internal addresses and recommended categories are in [Service configuration](docs/configuration.md).

## Start modes

```bash
./start.sh --core   # Jellyfin, Seerr, qBittorrent, Prowlarr, FlareSolverr, and Arr apps
./start.sh          # core plus all credential-free extras
./start.sh --all    # also enable automation services after adding API keys
./start.sh --check  # prepare and validate without starting containers
```

The `automation` profile contains Unpackerr, Recyclarr, and Notifiarr. Configure its API keys in `.env` before using `--all`.

## Storage

The default layout stays inside the repository and is ignored by Git:

```text
media/
├── Movies/
├── Series/
├── Anime/
└── Music/
downloads/
data/          # application databases and configuration
```

To use an existing library or external drive, edit these values in `.env` before starting:

```dotenv
MEDIA_DIR=/path/to/media
DOWNLOADS_DIR=/path/to/downloads
CONFIG_DIR=/path/to/app-data
```

See [Storage and permissions](docs/storage.md) for Linux, macOS, NAS, and external-drive guidance.

## Everyday commands

```bash
docker compose --profile extras ps
docker compose --profile extras logs -f jellyfin
docker compose --profile extras pull
docker compose --profile extras up -d
docker compose --profile extras down
```

`down` removes containers and networks, not your bind-mounted data. Do not add `-v` unless you understand what will be removed.

## Let an AI agent set it up

This repository includes an agent skill at [skills/setup-media-server/SKILL.md](skills/setup-media-server/SKILL.md). Give the repository to a compatible agent and ask:

> Use the setup-media-server skill to install and verify this stack on my machine.

The skill tells the agent how to inspect the host, preserve existing data, choose paths, run the setup, and verify the result.

## More detail

- [Service configuration](docs/configuration.md)
- [Storage and permissions](docs/storage.md)
- [Updates, backups, and recovery](docs/operations.md)

Use download and indexer tools only for content you are legally allowed to access.
