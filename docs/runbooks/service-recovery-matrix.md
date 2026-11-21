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

- [Media-stack recovery matrix](media-stack-recovery.md)
- `docs/runbooks/alert-runbook-map.md`
- `docs/runbooks/host-compromise-recovery.md`
- `docs/runbooks/sops-secret-compromise.md`
- `docs/runbooks/monitoring-outage.md`
- `docs/RECOVERY.md`
- `docs/SECRETS.md`
- `docs/audits/incident-response-recovery.md`
