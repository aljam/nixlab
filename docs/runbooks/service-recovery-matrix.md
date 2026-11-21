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
| pgAdmin | `r820` | PostgreSQL recovery is adjacent | Gap | Determine whether pgAdmin state is disposable or backed up; document recovery and administrative-access verification. |
| Matrix Synapse | `r730xd` | [Matrix recovery matrix](matrix-recovery-matrix.md); client and federation reachability alerts; Matrix secret rotation runbook | Covered | Maintain the recovery matrix and validate it during recovery exercises. |
| MatrixRTC / LiveKit | `r730xd` | [Matrix recovery matrix](matrix-recovery-matrix.md) RTC recovery section; RTC reachability alert | Covered | Maintain the RTC recovery procedure and validate it during recovery exercises. |
| Vaultwarden | `r730xd`, `r820` | Vaultwarden restore drill (`checks.x86_64-linux.vaultwarden-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| PeerTube | `r730xd` | PeerTube restore drill (`checks.x86_64-linux.peertube-restore-drill`); PostgreSQL password rotation runbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Radarr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Sonarr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Recyclarr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Autobrr | `r730xd` | Media-stack restore drill (`checks.x86_64-linux.media-stack-restore-drill`); SOPS secret compromise playbook | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Radio | `r730xd` | No dedicated procedure | Gap | Define stream and source recovery, listener verification, and dependency order. |
| Homepage | `r730xd` | Homepage restore drill (`checks.x86_64-linux.homepage-restore-drill`) | Covered | Maintain the restore drill and validate it during recovery exercises. |
| Static site | `r730xd` | [Public-service recovery matrix](public-service-recovery-matrix.md); public-service recovery drill (`checks.x86_64-linux.public-service-recovery-drill`) | Covered | Maintain the public-service recovery procedure and validate it during recovery exercises. |
| Restic backups | Multiple | [Restic restore drill](restic-restore-drill.md); backup failure and staleness alerts; backup documentation | Covered | Maintain the restore drill and validate it during recovery exercises. |
| NAS mounts | `navi`, `oryx` | SOPS secret compromise playbook | Partial | Define mount recovery, credential-rotation effects, and data-access verification. |
| ZFS / Sanoid | Server hosts | Backup and disk-health alerts | Partial | Define pool import, snapshot verification, and recovery-point validation. |
| Grafana | Monitoring host | [Monitoring outage response](monitoring-outage.md) | Covered | Maintain the monitoring outage procedure and validate it during recovery exercises. |
| Loki | Monitoring host | Loki restore drill (`checks.x86_64-linux.loki-restore-drill`); [Monitoring outage response](monitoring-outage.md) | Covered | Maintain the restore drill and monitoring outage procedure; validate them during recovery exercises. |
| ntfy relay | Monitoring host | [Monitoring outage response](monitoring-outage.md); alert-delivery validation | Covered | Maintain the monitoring outage procedure and validate it during recovery exercises. |

## Prioritized follow-up

Address gaps in this order:

1. **pgAdmin recovery** — determines whether administrative state is disposable or requires backup and recovery coverage.
2. **Radio recovery** — defines stream and source recovery, listener verification, and dependency order.
3. **NAS mount recovery** — defines mount recovery, credential-rotation effects, and data-access verification.
4. **ZFS / Sanoid recovery** — defines pool import, snapshot verification, and recovery-point validation.

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
- `docs/runbooks/alert-runbook-map.md`
- `docs/runbooks/host-compromise-recovery.md`
- `docs/runbooks/sops-secret-compromise.md`
- `docs/RECOVERY.md`
- `docs/SECRETS.md`
- `docs/audits/incident-response-recovery.md`
