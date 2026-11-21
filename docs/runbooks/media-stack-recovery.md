# Media-stack recovery matrix

This runbook defines the recovery order and verification steps for the media automation stack on `r730xd`. It treats qBittorrent, the Servarr applications, Shoko, Jellyfin, Autobrr, and Recyclarr as one dependency graph rather than as isolated services.

Use this runbook after a host rebuild, storage recovery, backup restoration, credential compromise, or extended service outage. Do not restore service state directly over live production data without first preserving the current state and confirming that the target is an isolated recovery environment.

## Scope

This runbook covers:

- qBittorrent
- Radarr
- Sonarr
- Lidarr
- Bazarr
- Prowlarr
- Seerr
- Shoko
- Jellyfin
- Autobrr
- Recyclarr

It does not replace the generic [Restic restore drill](restic-restore-drill.md), [PostgreSQL restore drill](postgresql-restore-drill.md), or host-compromise recovery procedure. Use those procedures first when the underlying host, PostgreSQL instance, or Restic repository requires recovery.

## Recovery dependencies

| Component | Persistent state | Depends on | Recovery role |
|---|---|---|---|
| Media mount | Media files | Host storage and NAS availability | Must be available before service validation |
| qBittorrent | Service configuration and torrent state | Media mount, inbound swarm connectivity | Restore before automation services |
| Prowlarr | Indexer configuration and credentials | External indexer availability | Restore before Radarr and Sonarr validation |
| Radarr | Service database and configuration | qBittorrent, Prowlarr, media mount | Restore before Recyclarr |
| Sonarr | Service database and configuration | qBittorrent, Prowlarr, media mount | Restore before Seerr validation |
| Lidarr | Service database and configuration | qBittorrent, Prowlarr, media mount | Restore with the other Servarr services |
| Bazarr | Service database and configuration | Radarr, Sonarr, media mount | Restore after Radarr and Sonarr |
| Seerr | Request and integration state | Radarr and Sonarr APIs | Restore after Radarr and Sonarr |
| Shoko | Library and service state | Media mount | Restore after the media mount is healthy |
| Jellyfin | Metadata and configuration | Media mount | Restore after the media mount is healthy |
| Autobrr | `/var/lib/autobrr` | qBittorrent and tracker credentials | Restore after qBittorrent is healthy |
| Recyclarr | None; configuration is generated | Radarr API and SOPS-managed API key | Run last, after Radarr is healthy |

## Recovery order

Perform the steps in this order. Do not proceed to the next phase until the checks for the current phase pass.

1. **Recover the media mount.**
2. **Recover qBittorrent.**
3. **Recover Prowlarr.**
4. **Recover Radarr, Sonarr, Lidarr, and Bazarr.**
5. **Recover Seerr.**
6. **Recover Shoko and Jellyfin.**
7. **Recover Autobrr.**
8. **Run Recyclarr synchronization.**

## Media mount recovery

The Servarr stack uses `/mnt/media` as its shared media tree. The directory is setgid `media`, and Servarr services use `UMask = 0002` so newly created files remain writable by the shared `media` group.

Verify:

- `/mnt/media` is mounted.
- The mount is writable by the expected `media` group.
- Existing media directories retain the expected ownership and group-write permissions.
- A representative existing media file can be read by a Servarr service user.
- A representative new file can be created in the intended download or media path.

Do not proceed until the media mount is healthy. A service may start successfully while remaining unable to import, rename, move, or serve media.

## qBittorrent recovery

qBittorrent is the download client for the stack. Its inbound swarm port is TCP and UDP `6881`; this is the only port in the media stack that is deliberately reachable from outside the gateway.

Verify:

- `qbittorrent.service` is active.
- The qBittorrent web UI responds on port `8080`.
- The configured download directory is on the recovered media mount.
- qBittorrent can write a representative completed download to the media tree.
- TCP and UDP port `6881` remain allowed by the host firewall.
- Representative torrent state is present or has been restored from an approved recovery point.
- A representative torrent can be checked, resumed, or seeded without a storage error.

If torrent state cannot be recovered, record the loss and identify affected downloads before proceeding. Do not silently recreate torrent state.

## Prowlarr recovery

Prowlarr coordinates indexer configuration for the automation services.

Verify:

- `prowlarr.service` is active.
- The web UI responds on port `9696`.
- Indexer definitions are present or have been restored from an approved recovery point.
- A representative indexer can complete a search or connectivity test.
- Credentials remain functional and are not exposed in logs or command output.

If indexer credentials are unavailable, document the affected indexers and pause dependent automation validation until they are restored or rotated.

## Servarr recovery

Recover Radarr, Sonarr, Lidarr, and Bazarr after qBittorrent and Prowlarr are healthy.

Verify for each applicable service:

- The service is active.
- Its web UI responds on its configured port.
- Its database and configuration state are restored from an approved recovery point.
- Its qBittorrent download-client integration is configured and can authenticate.
- Its Prowlarr indexer integration is configured and can communicate with Prowlarr.
- A representative library item can be inspected without a database or media-path error.
- A representative import, rename, or move operation can be performed in an isolated staging environment.

Service ports are:

| Service | Port |
|---|---:|
| Radarr | 7878 |
| Sonarr | 8989 |
| Lidarr | 8686 |
| Bazarr | 6767 |
| Prowlarr | 9696 |
| Seerr | 5055 |
| Jellyfin | 8096 |
| qBittorrent | 8080 |

## Seerr recovery

Seerr depends on Radarr and Sonarr APIs. Restore it only after both services are reachable and their integrations have been validated.

Verify:

- `seerr.service` is active.
- The web UI responds on port `5055`.
- Radarr and Sonarr integrations can authenticate.
- A representative request can be created or inspected.
- Request state is restored from an approved recovery point or its loss is explicitly documented.

## Shoko and Jellyfin recovery

Shoko and Jellyfin depend primarily on the media mount. Shoko is intentionally LAN-only and must not be exposed through the HAProxy backend allowlist.

Verify:

- `shoko.service` is active.
- Shoko can access its library and media paths.
- `jellyfin.service` is active.
- Jellyfin can enumerate a representative library.
- A representative media item can be played or its metadata can be inspected.
- Shoko remains unavailable through the public reverse-proxy backend allowlist.

## Autobrr recovery

Autobrr has a dedicated system user, hardened systemd service, and writable state at `/var/lib/autobrr`. It binds to the host service address rather than all interfaces and is exposed through the reverse-proxy backend allowlist on port `7474`.

Verify:

- `/var/lib/autobrr` is restored with the correct ownership.
- `autobrr.service` is active.
- Autobrr binds to the configured host service address, not `0.0.0.0`.
- The web UI responds on port `7474`.
- The qBittorrent integration can authenticate.
- Tracker credentials are present and functional.
- A representative release or download action can be tested in an isolated environment.

Do not paste tracker credentials, API keys, or authentication material into incident records, logs, or pull requests.

## Recyclarr recovery

Recyclarr is a oneshot configuration-synchronization service. It has no persistent writable state; it reads a generated configuration and the SOPS-managed Radarr API key, then synchronizes configuration into Radarr.

Run Recyclarr only after Radarr is reachable and its API integration has been validated.

Verify:

- The SOPS-managed `radarr_api_key` is deployed with the expected ownership and permissions.
- `recyclarr.service` completes successfully.
- Recyclarr reports a successful synchronization with Radarr.
- Radarr retains the expected quality-profile or configuration changes.
- Restarting `recyclarr.service` is performed after rotating or restoring `radarr_api_key`.

## Secret recovery

| Secret or credential | Storage | Recovery action |
|---|---|---|
| `radarr_api_key` | SOPS-managed secret | Restore or rotate through the normal SOPS deployment path, then restart `recyclarr.service` |
| Service API keys and credentials | Service state | Restore from an approved recovery point or rotate manually if state is unrecoverable |
| Indexer credentials | Prowlarr state | Restore from an approved recovery point or rotate manually |
| Tracker credentials | Autobrr state | Restore from an approved recovery point or rotate manually |
| qBittorrent credentials | qBittorrent state | Restore from an approved recovery point or rotate manually |

If a credential may have been exposed, rotate it before restoring the affected service. Follow the [SOPS secret compromise runbook](sops-secret-compromise.md) for SOPS-managed material.

## Completion criteria

The media stack is not recovered until all of the following are true:

- The media mount is mounted, writable, and preserves the expected ownership model.
- qBittorrent can access its download directory and the swarm port remains available.
- Prowlarr, Radarr, Sonarr, Lidarr, Bazarr, Seerr, Shoko, Jellyfin, and Autobrr are active.
- Representative API integrations and media operations succeed.
- Recyclarr completes a successful synchronization against Radarr.
- Monitoring is healthy and no unexpected media-stack alerts remain active.
- The recovery actions, failed checks, credential rotations, and final validation results are recorded in the incident record.

## Related documentation

- [Restic restore drill](restic-restore-drill.md)
- [PostgreSQL restore drill](postgresql-restore-drill.md)
- [Service recovery and verification inventory](service-recovery-matrix.md)
- [SOPS secret compromise](sops-secret-compromise.md)
- [Host compromise recovery](host-compromise-recovery.md)
- [Incident evidence preservation](incident-evidence.md)
