# Alert runbook map

Use this map to choose the initial response path for a Prometheus alert. It covers alerts defined by the repository’s Prometheus, drift, and host-baseline rule files.

An alert is a detection signal, not a diagnosis. Confirm the affected host, service, revision, credentials, and logs before taking recovery action.

## Response principles

- Treat critical alerts as immediate operational priorities.
- Treat warnings as investigation and planning signals unless they indicate an active security boundary change.
- Do not clear an alert until its underlying condition is verified as resolved.
- If monitoring itself is unavailable, use direct checks and follow `docs/runbooks/monitoring-outage.md`.
- If unauthorized configuration, listener, firewall, or deployment activity is suspected, follow `docs/runbooks/host-compromise-recovery.md`.

## Host and capacity

| Alert | Severity | Initial response |
|---|---:|---|
| `NodeDown` | critical | Follow `docs/runbooks/monitoring-outage.md`; verify host reachability and node-exporter directly. |
| `FilesystemAlmostFull` | warning | Investigate capacity growth, remove unnecessary data, and plan expansion before the filesystem becomes critical. |
| `FilesystemFull` | critical | Protect data, identify growth, free capacity or expand storage, and verify service health. |
| `SystemdUnitFailed` | warning | Identify the failed unit and follow its service-specific recovery procedure. |
| `FailedSystemUnits` | warning | Identify failed system units and follow their service-specific recovery procedures. |
| `FailedUserUnits` | warning | Identify failed user units and follow the relevant user-service recovery procedure. |
| `HostMemoryPressure` | warning | Identify memory consumers, check for leaks or unexpected processes, and plan capacity or service changes. |

## Backups

| Alert | Severity | Initial response |
|---|---:|---|
| `ResticBackupFailed` | critical | Inspect the backup unit journal, repository availability, credentials, and lock state; preserve evidence before changing repository state. |
| `ResticBackupStale` | warning | Verify the last successful backup, repository integrity, schedule, and whether the backup host or repository is reachable. |

## Disk health

| Alert | Severity | Initial response |
|---|---:|---|
| `SmartHealthFailed` | critical | Stop using the affected device for new data, verify backups and pool redundancy, and plan replacement. |
| `DiskTemperatureHigh` | warning | Check airflow, fans, drive placement, and workload; monitor the temperature trend. |
| `DiskTemperatureCritical` | critical | Investigate cooling immediately; reduce avoidable load and protect data while investigating. |
| `DiskReallocatedSectors` | warning | Monitor the trend, run non-destructive diagnostics where appropriate, and plan replacement if degradation continues. |
| `DiskPendingSectors` | warning | Run non-destructive diagnostics, monitor the trend, and prepare for replacement if pending sectors do not clear. |

## Public services

| Alert | Severity | Initial response |
|---|---:|---|
| `PublicEndpointDown` | critical | Check pfSense HAProxy, DNS, certificate renewal, and the backend service; follow the relevant public-service recovery procedure. |
| `PublicCertificateExpiringSoon` | warning | Verify automated certificate renewal and ensure the replacement certificate will deploy before expiry. |
| `PublicCertificateExpiringCritical` | critical | Renew and deploy the certificate immediately; verify the public endpoint and TLS chain afterward. |

## Matrix

| Alert | Severity | Initial response |
|---|---:|---|
| `MatrixClientAPIUnreachable` | critical | Check the Matrix service, reverse proxy, DNS, TLS, and client API endpoint. |
| `MatrixFederationAPIUnreachable` | critical | Check the Matrix server, federation endpoint, DNS, TLS, and upstream network access. |
| `MatrixRTCUnreachable` | critical | Check MatrixRTC, its frontend, reverse proxy, DNS, TLS, and dependent services. |

## PostgreSQL

| Alert | Severity | Initial response |
|---|---:|---|
| `PostgreSQLUnreachable` | critical | Check PostgreSQL service status, network reachability, firewall policy, and host health. |
| `PostgreSQLTLSVerificationFailed` | critical | Check the PostgreSQL TLS certificate, certificate chain, service configuration, and client verification path. |
| `PostgreSQLCertificateExpiringSoon` | warning | Verify automated certificate renewal and ensure the replacement certificate will deploy before expiry. |
| `PostgreSQLCertificateExpiringCritical` | critical | Renew and deploy the PostgreSQL certificate immediately; verify TLS afterward. |

## Drift and security

| Alert | Severity | Initial response |
|---|---:|---|
| `NixOSRevisionDrift` | warning | Identify the deployed and expected revisions; reconcile the host with an authorized revision. |
| `CriticalServiceFailed` | critical | Identify the failed critical unit and follow its service-specific recovery procedure. |
| `UnexpectedListeningSocket` | warning | Identify the process and port; determine whether it is authorized and assess its exposure. |
| `FirewallRulesetChanged` | warning | Determine whether the change came from a reviewed deployment; otherwise investigate unauthorized change. |
| `NftablesRulesetDrift` | warning | Determine whether the change came from a reviewed deployment; otherwise investigate unauthorized change. |
| `ListeningTCPSocketsIncreased` | warning | Identify newly listening services and determine whether they are authorized and intentionally exposed. |
| `DeploymentRevisionUnknown` | critical | Freeze deployment activity, identify the running revision, and follow `docs/runbooks/host-compromise-recovery.md` if unauthorized change is suspected. |

## Security escalation

Route an alert to `docs/runbooks/host-compromise-recovery.md` when any of the following cannot be attributed to an authorized deployment:

- Configuration revision drift.
- Unknown or dirty deployment revision.
- Unexpected listening socket.
- Firewall or nftables ruleset change.
- Unexpected increase in listening TCP sockets.

Preserve evidence before rebuilding or replacing the host. Do not assume that a reverted configuration removes the need to investigate credentials, secrets, or persistence.

## Related documentation

- `docs/runbooks/incident-severity.md`
- `docs/runbooks/monitoring-outage.md`
- `docs/runbooks/host-compromise-recovery.md`
- `docs/runbooks/sops-secret-compromise.md`
- `docs/MONITORING.md`
- `docs/audits/incident-response-recovery.md`
