# Updates, backups, and recovery

## Check status and logs

```bash
docker compose --profile extras ps
docker compose --profile extras logs -f --tail=200
docker compose --profile extras logs -f jellyfin
```

For automation services, add `--profile automation` to the command.

## Update images

```bash
docker compose --profile extras pull
docker compose --profile extras up -d
docker image prune
```

Review release notes for database-bearing services before major upgrades. Updates are deliberately manual so a new image cannot replace a working service without an operator choosing to do so.

## What to back up

Back up:

- `.env`;
- everything under `CONFIG_DIR` (default `./data`);
- custom Recyclarr configuration;
- any media that cannot be recreated.

Downloads are normally transient. Config directories contain databases, users, credentials, and API keys, so keep backups private.

The bundled Jellyfin helper creates a small configuration-focused archive:

```bash
./scripts/backup-jellyfin.sh
```

When using non-default paths:

```bash
JELLYFIN_CONFIG_DIR=/srv/media-server/config/jellyfin \
BACKUP_DIR=/srv/backups/jellyfin \
./scripts/backup-jellyfin.sh
```

## Restore on another machine

1. Install Docker Compose v2 and clone the repository.
2. Restore `.env` and `CONFIG_DIR`.
3. Mount or restore the media and download paths named in `.env`.
4. Run `./start.sh --check` to validate without starting containers.
5. Run `./start.sh`, then inspect `docker compose --profile extras ps` and application logs.

Do not use `docker compose down -v` as a troubleshooting shortcut. The current stack uses bind mounts, but the `-v` habit can destroy named volumes added by local overrides.

## Reverse proxy and remote access

The repository intentionally publishes ordinary host ports and does not assume a DNS provider, domain, VPN, certificate resolver, or reverse proxy. Put Caddy, Traefik, Nginx Proxy Manager, a VPN, or a tunnel in front of those ports according to your environment.

Do not expose administrative applications directly to the public internet without authentication and transport security.
