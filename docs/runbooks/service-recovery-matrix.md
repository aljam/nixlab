# Service recovery and verification inventory

This inventory identifies recovery and verification coverage for stateful, public, security-sensitive, and externally integrated services. It is a planning document: it records existing coverage and gaps, but does not replace a service-specific recovery runbook.

Use the alert runbook map to choose an initial response path. Use the host-compromise runbook when unauthorized change, credential exposure, or host compromise is suspected.

## Scope

This inventory covers services with one or more of the following properties:

- Persistent application or database state.
- Public exposure.
- Security-sensitive credentials or user data.
- External service integrations.
- Dependence on backups, certificates, reverse proxies, or monitoring.

Desktop conveniences and host-local development features are out of scope unless they affect fleet recovery.

## Coverage status

| Status | Meaning |
|---|---|
| Covered | A service-specific or directly applicable recovery procedure exists. |
| Partial | Detection, secret rotation, or a related recovery procedure exists, but end-to-end recovery is incomplete. |
| Gap | No dedicated recovery and verification procedure exists. |

## Service inventory

| Service | Host(s) | Existing coverage | Status | Gap and follow-up |
|---|---|---|---|---|
| PostgreSQL | `r820` | [PostgreSQL restore drill](postgresql-restore-drill.md); PostgreSQL reachability and TLS alerts | Covered | Maintain the restore drill and validate it during recovery exercises. |
| pgAdmin | `r820` | SOPS-managed password; loopback-only administrative service; PostgreSQL recovery is adjacent | Covered | pgAdmin state is disposable. After a host rebuild, redeploy pgAdmin, restore its SOPS-managed password, and recreate administrative connections as needed. Do not treat pgAdmin state as a recovery-point objective. |
| Matrix Synapse | `r730xd` | [Matrix recovery matrix](matrix-recovery-matrix.md); client and federation reachability alerts; Matrix secret rotation runbook | Covered | Maintain the recovery matrix and validate it during recovery exercises. |
| MatrixRTC / LiveKit | `r730xd` | [Matrix recovery matrix](matrix-recovery-matrix.md) RTC recovery section; RTC reachability alert | Covered | Maintain the RTC recovery procedure and validate it during recovery exercises. |
| Vaultwarden | `r730xd`, `r820` | Vaultwarden restore drill (`checks.x86_64-linux.vaultwarden-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| PeerTube | `r730xd` | PeerTube restore drill (`checks.x86_64-linux.peertube-restore-drill`); PostgreSQL password rotation runbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Radarr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Sonarr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Recyclarr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Autobrr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Radio | `r730xd` | Declarative Icecast and Liquidsoap configuration; SOPS-managed streaming credentials; shared media-library recovery; local nginx front end | Covered | Recover the music library and SOPS-managed credentials, redeploy the authorized revision, then validate the local stream and public radio endpoint. Icecast logs are diagnostic only and are not a recovery-point objective. |
| Homepage | `r730xd` | Homepage restore drill (`checks.x86_64-linux.homepage-restore-drill`) | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Static site | `r730xd` | [Public-service recovery matrix](public-service-recovery-matrix.md); public-service recovery drill (`checks.x86_64-linux.public-service-recovery-drill`) | Covered | Maintain the public-service recovery procedure and validate it during recovery exercises. |
| Restic backups | Multiple | [Restic restore drill](restic-restore-drill.md); backup failure and staleness alerts; backup documentation | Covered | Maintain the restore drill and validate it during recovery exercises. |
| NAS mounts | `navi`, `oryx` | Declarative CIFS mount; SOPS-managed NAS credentials; manual remount after credential rotation | Covered | Verify NAS reachability, deploy the SOPS-managed credential, mount `/mnt/share`, validate read/write access, and remount after credential rotation. |
| ZFS / Sanoid | Server hosts | Sanoid automated snapshots and pruning; `mediapool/media` and `mediapool/root` protected datasets; backup and disk-health alerts | Covered | Recover the required ZFS pool and datasets from a validated Sanoid snapshot, then confirm pool health, dataset availability, and service recovery. |
| Grafana | Monitoring host | [Monitoring outage response](monitoring-outage.md) | Covered | Maintain the monitoring outage procedure and validate it during recovery exercises. |
| Loki | Monitoring host | Loki restore drill (`checks.x86_64-linux.loki-restore-drill`); [Monitoring outage response](monitoring-outage.md) | Covered | Maintain the restore drill and monitoring outage procedure; validate them during recovery exercises. |
| ntfy relay | Monitoring host | [Monitoring outage response](monitoring-outage.md); alert-delivery validation | Covered | Maintain the monitoring outage procedure and validate it during recovery exercises. |

## pgAdmin recovery

pgAdmin is loopback-only administrative tooling for PostgreSQL. Its persistent state is disposable and is not a recovery-point objective.

After a host rebuild or pgAdmin state loss:

1. Deploy the authorized NixOS revision.
2. Confirm the SOPS-managed `pgadmin_password` is deployed with the expected ownership and permissions.
3. Start `pgadmin.service`.
4. Confirm pgAdmin listens only on `127.0.0.1:5050`.
5. Confirm that pgAdmin is not exposed through HAProxy or the public Homepage.
6. Authenticate with the recovered SOPS-managed password.
7. Recreate required PostgreSQL server connections and administrative settings.
8. Confirm PostgreSQL remains reachable with `sslmode=verify-full`.

Do not restore pgAdmin state over a newer deployment. If pgAdmin state is unavailable, recreate it rather than treating its loss as a PostgreSQL recovery failure.

## Radio recovery

Radio is a declarative streaming stack: Liquidsoap reads music from the shared media mount and streams to loopback-only Icecast. The public radio endpoint is served by the local nginx front end.

The music library is the primary recovery artifact. Icecast and Liquidsoap configuration is generated from SOPS templates, and neither service has critical persistent state beyond diagnostic logs.

After a host rebuild, media-storage recovery, or Radio outage:

1. Deploy the authorized NixOS revision.
2. Recover and validate `/mnt/media/music`.
3. Confirm the SOPS-managed `icecast_source_password` and `icecast_admin_password` are deployed with the expected ownership and permissions.
4. Start `icecast.service`.
5. Start `liquidsoap-radio.service`.
6. Confirm Icecast remains bound to `127.0.0.1:8000`.
7. Confirm Liquidsoap can read a representative music file from the recovered library.
8. Confirm the local nginx radio front end reaches Icecast.
9. Confirm the public radio endpoint returns the expected stream or status response.
10. Confirm that restarting either streaming service does not expose Icecast directly to the network.

Do not treat Icecast logs as a recovery-point objective. If the music library is unavailable, recover it before attempting to validate the stream.

## NAS mount recovery

NAS mounts use a declarative CIFS configuration and SOPS-managed credentials. The NAS is the authoritative storage system; the local mount is a client-side access path.

After a host rebuild, NAS outage, credential rotation, or mount failure:

1. Confirm the NAS is reachable at its configured fleet address.
2. Confirm the SOPS-managed `nas-credentials` secret is deployed with the expected ownership and permissions.
3. Confirm `/mnt/share` is mounted.
4. Confirm the mount uses the expected CIFS device and options.
5. Confirm a representative file can be read from the share.
6. Confirm a representative file can be created, modified, or removed in an approved test location.
7. Confirm dependent workloads can access the share with the expected ownership and permissions.
8. If credentials were rotated, remount `/mnt/share` deliberately after confirming that active workloads will not be disrupted.

Do not restart or remount the share automatically after credential rotation. The configuration intentionally requires a manual remount to avoid disrupting active workloads.

## ZFS / Sanoid recovery

ZFS provides the underlying storage for protected datasets, while Sanoid provides automated snapshots and pruning. The recovery objective is to restore a required dataset to a known-good snapshot and validate that dependent services can access the recovered data.

The protected datasets are:

- `mediapool/media`
- `mediapool/root`

Sanoid retains hourly, daily, weekly, and monthly snapshots for these datasets. The selected snapshot is the recovery point; its age and completeness determine the recovery-point objective.

After a dataset corruption, accidental deletion, host rebuild, or storage outage:

1. Confirm the ZFS pool is importable and healthy.
2. Identify the newest known-good Sanoid snapshot for the affected dataset.
3. Confirm the selected snapshot exists and has the expected creation time.
4. Recover the affected dataset from the selected snapshot.
5. Confirm the recovered dataset is mounted and readable.
6. Confirm representative files or directories are present and readable.
7. Confirm dependent workloads can access the recovered dataset.
8. Confirm Sanoid snapshot creation resumes after recovery.
9. Confirm ZFS pool health and disk-health monitoring are healthy.
10. Record the selected snapshot, recovery time, and validation evidence in the incident record.

Do not treat snapshot retention as a substitute for a validated restore. A snapshot is not a recovery point until it has been restored or otherwise validated.
| PostgreSQL | `r820` | `docs/RECOVERY.md`; PostgreSQL reachability and TLS alerts | Partial | Add a restore-readiness drill: validate backup age, restore to an isolated target, verify schema and data, then verify application connectivity. |
| pgAdmin | `r820` | PostgreSQL recovery is adjacent | Gap | Determine whether pgAdmin state is disposable or backed up; document recovery and administrative-access verification. |
| Matrix Synapse | `r730xd` | Client and federation reachability alerts; Matrix secret rotation runbook | Partial | Add database and media recovery, federation verification, and administrator-access recovery. |
| MatrixRTC / LiveKit | `r730xd` | RTC reachability alert | Gap | Define recovery order, secret dependencies, and call or connectivity verification. |
| Vaultwarden | `r730xd`, `r820` | SOPS secret compromise playbook | Partial | Define database and attachment recovery, admin-token rotation, and user-access verification. |
| PeerTube | `r730xd` | PostgreSQL password rotation runbook | Partial | Add media-storage recovery, database restore, and upload or playback verification. |
| Radarr | `r730xd` | [Media-stack recovery matrix](media-stack-recovery.md) | Covered | Maintain the recovery procedure and validate it during recovery exercises. |
| Sonarr | `r730xd` | [Media-stack recovery matrix](media-stack-recovery.md) | Covered | Maintain the recovery procedure and validate it during recovery exercises. |
| Recyclarr | `r730xd` | [Media-stack recovery matrix](media-stack-recovery.md) | Covered | Maintain the recovery procedure and validate it during recovery exercises. |
| Autobrr | `r730xd` | [Media-stack recovery matrix](media-stack-recovery.md) | Covered | Maintain the recovery procedure and validate it during recovery exercises. |
| Radio | `r730xd` | No dedicated procedure | Gap | Define stream and source recovery, listener verification, and dependency order. |
| Homepage | `r730xd` | No dedicated procedure | Gap | Determine whether configuration is declarative or persistent; document recovery and link verification. |
| Static site | `r730xd` | No dedicated procedure | Gap | Define content or source recovery and verify the public endpoint. |
| Restic backups | Multiple | Backup failure and staleness alerts; backup documentation | Partial | Add a periodic restore drill with scoped data validation and retention checks. |
| NAS mounts | `navi`, `oryx` | SOPS secret compromise playbook | Partial | Define mount recovery, credential-rotation effects, and data-access verification. |
| ZFS / Sanoid | Server hosts | Backup and disk-health alerts | Partial | Define pool import, snapshot verification, and recovery-point validation. |
| Grafana | Monitoring host | Monitoring outage runbook | Partial | Define dashboard and data-source recovery, then verify operator access. |
| Loki | Monitoring host | Monitoring outage runbook | Partial | Define ingestion recovery, retention validation, and query verification. |
| ntfy relay | Monitoring host | Alert-delivery validation | Partial | Define relay recovery and end-to-end notification verification. |

## Prioritized follow-up

Address gaps in this order:

1. **PostgreSQL restore drill** — validates the recovery path for multiple dependent services.
2. **Matrix recovery matrix** — covers a public, stateful service with database, media, federation, and RTC dependencies.
3. **Restic restore drill** — proves that backups are usable, not merely present.
4. **Vaultwarden recovery** — protects a high-value credential store.
5. **PeerTube media recovery** — connects database, media storage, and public playback verification.
6. **Public-site and Homepage recovery** — defines simple, repeatable content and endpoint verification.

## Verification standard

Every future service-specific recovery runbook should define:

- The recovery-point source and its expected freshness.
- The recovery order for databases, media, secrets, and services.
- The commands or procedures required to restore service state.
- The security credentials or secrets that must be rotated.
- The functional checks that prove the service is usable.
- The monitoring checks and alerts that must clear.
- The evidence and incident-record requirements.

A service is not recovered until its functional checks pass, its monitoring is healthy, and its recovery point has been validated.

## Related documentation

- [Matrix recovery matrix](matrix-recovery-matrix.md)
- [PostgreSQL restore drill](postgresql-restore-drill.md)
- [Public-service recovery matrix](public-service-recovery-matrix.md)
- [Restic restore drill](restic-restore-drill.md)
- [Monitoring outage response](monitoring-outage.md)
- [Media-stack recovery matrix](media-stack-recovery.md)
- `docs/runbooks/alert-runbook-map.md`
- `docs/runbooks/host-compromise-recovery.md`
- `docs/runbooks/sops-secret-compromise.md`
- `docs/RECOVERY.md`
- `docs/SECRETS.md`
- `docs/audits/incident-response-recovery.md`
