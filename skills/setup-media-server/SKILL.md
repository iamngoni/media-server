---
name: setup-media-server
description: Install, configure, migrate, or troubleshoot the Docker Compose media-server stack in this repository. Use when an agent is asked to set up the stack on Linux or macOS, choose media/config/download paths, start core/extras/automation profiles, preserve or migrate existing application data, or verify services after deployment.
---

# Set up the media server

Treat the repository containing this skill as the source of truth. Resolve its root two directories above this file, then work from that directory.

## Read the setup surface

Read these files before changing or starting anything:

- `README.md`
- `.env.example`
- `docker-compose.yml`
- `docs/storage.md` when storage is external or pre-existing
- `docs/configuration.md` when wiring applications together
- `docs/operations.md` when migrating, updating, or restoring

## Protect existing installations

1. Run `git status --short --branch` and `docker compose ps` to identify existing work and containers.
2. Preserve an existing `.env`; the setup script deliberately leaves it unchanged.
3. Treat `CONFIG_DIR`, `MEDIA_DIR`, and `DOWNLOADS_DIR` as user data. Do not delete, replace, relocate, or recursively change ownership without explicit approval.
4. Never use `docker compose down -v` as a troubleshooting step.
5. Do not expose applications publicly or configure DNS, tunnels, certificates, or router changes unless the user explicitly requests remote access.

## Choose a start mode

- Use `./start.sh` for a normal new installation. It starts the core stack and credential-free extras.
- Use `./start.sh --core` when the user wants a smaller footprint.
- Use `./start.sh --all` only after the automation API keys and Recyclarr configuration are present, or when the user explicitly accepts partially configured automation services.
- Use `./start.sh --check` while preparing or diagnosing. It creates missing local defaults and validates Compose without starting containers.

When the request says “set up everything” without other constraints, use the normal `./start.sh` mode. Do not interpret “everything” as permission to expose services publicly.

## Prepare the host

1. Verify `docker`, `docker compose`, and a running Docker daemon.
2. On a fresh local installation, let `./start.sh --check` generate `.env` and directories.
3. When the user names existing or external storage, set these `.env` values before starting:

   ```dotenv
   CONFIG_DIR=/path/to/application-data
   MEDIA_DIR=/path/to/media
   DOWNLOADS_DIR=/path/to/downloads
   ```

4. Use the current user's `id -u` and `id -g` for `PUID` and `PGID` unless the storage owner requires another account.
5. Confirm that the selected paths exist, are mounted, and are writable by that user. Avoid recursive ownership changes on existing libraries.
6. Run `./start.sh --check` and resolve every Compose interpolation, path, or port error before starting containers.

## Start and verify

1. Run the selected `start.sh` mode.
2. Run the matching status command:

   ```bash
   docker compose --profile extras ps
   ```

   Add `--profile automation` when `--all` was used.

3. Investigate every container that is exited, restarting, or unhealthy with `docker compose logs --tail=200 <service>`.
4. Check at least Jellyfin, qBittorrent, Sonarr, Radarr, Prowlarr, and Seerr from their configured host ports. Accept redirects where an application normally redirects to login or setup.
5. Read the qBittorrent temporary password from its logs and tell the user to replace it with a permanent password.
6. If requested to finish application wiring, follow `docs/configuration.md` and use Compose service names for container-to-container addresses.

## Report the result

State:

- which start mode was used;
- the resolved config, media, and download paths without revealing secrets;
- which containers and HTTP surfaces were verified;
- any service still awaiting first-run UI configuration or API keys;
- the exact next action when something remains incomplete.

Do not claim the installation is healthy merely because `docker compose up` returned successfully. Base that claim on container state, relevant logs, mounted paths, and reachable application endpoints.
