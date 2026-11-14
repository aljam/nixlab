# Incident response and recovery readiness audit

## Goal

Determine whether the fleet can detect, contain, recover from, and verify
recovery from high-impact operational and security incidents.

This audit connects existing controls rather than duplicating them. It maps
monitoring, alerting, logging, backups, access controls, deployment
boundaries, and recovery documentation to the incident lifecycle.

## Existing controls

| Capability | Existing evidence |
|---|---|
| Recovery procedures | `docs/RECOVERY.md` covers SOPS host recovery, PostgreSQL recovery, and post-recovery verification. |
| Runbooks | `docs/runbooks/` includes Loki firewall access, Matrix reCAPTCHA rotation, and PeerTube PostgreSQL password rotation. |
| Backup recovery | Restic repository integrity and restore-readiness work already exists. |
| Detection | Prometheus, Alertmanager, Loki, drift monitoring, and configuration-change monitoring are present. |
| Access containment | SSH hardening, deploy-user restrictions, fail2ban policy, and audit logging already exist. |
| Secret recovery | SOPS recovery readiness and host recipient rotation are implemented. |

## Incident lifecycle

For every high-impact scenario, assess:

1. **Detect** — Which alert, log query, dashboard, or external signal identifies the event?
2. **Triage** — How does the operator determine scope, severity, affected host or service, and whether the event is security-related?
3. **Contain** — Which immediate, reversible actions limit impact without making recovery harder?
4. **Eradicate** — How are the root cause, compromised credential, malicious change, or failed dependency removed?
5. **Recover** — Which restore, redeploy, secret-rotation, or service-restart procedure applies?
6. **Verify** — Which health checks, alerts, logs, and functional tests prove recovery?
7. **Learn** — What evidence is retained, what follow-up is created, and what configuration or runbook changes result?

## Scenario matrix

| Scenario | Detection | Containment | Recovery | Verification | Initial assessment |
|---|---|---|---|---|---|
| Compromised SSH key or deploy identity | Authentication and audit logs; failed or unexpected deployment activity | Revoke or rotate credentials; disable deployment authorization if confirmed | Rebuild or replace the host; reauthorize SOPS recipients; restore state where required | SSH policy, deployment authorization, monitoring, backups, and critical-service health | Runbook needed |
| Leaked SOPS secret | External provider notice, secret-scanning result, or operator report | Revoke the exposed upstream credential where possible | Rotate the SOPS secret; restart or reload declared consumers | Service health, authentication, and relevant alerts | Cross-service runbook needed |
| Public service compromise | Availability, authentication, application, or proxy alerts; application logs | Disable or restrict the affected service; preserve evidence | Remove malicious change; restore known-good configuration or data; redeploy | Public endpoint health, authentication, logs, and alert clearance | Service-specific recovery matrix needed |
| Database compromise or corruption | PostgreSQL authentication, TLS, reachability, or application alerts | Revoke compromised database roles; restrict network access if needed | Restore from a verified backup; recreate or rotate credentials | Database connectivity, application health, backup integrity, and TLS checks | Recovery procedure exists for PostgreSQL; broaden verification coverage |
| Backup failure | Failed or stale backup alerts; Restic integrity or restore checks | Prevent further writes to a potentially corrupted repository; preserve evidence | Repair or replace the repository; restore from a known-good recovery point | Repository integrity, restore test, backup freshness, and application recovery | Existing controls are strong; define escalation path |
| Configuration drift | Drift monitoring; Nix, systemd, PAM, or DNS change monitoring | Freeze deployment authorization if unauthorized change is suspected | Revert to the authorized configuration revision; rotate credentials if compromise is confirmed | Drift check, service health, deployment boundary, and audit logs | Rollback and attribution procedure needed |
| Certificate failure | Certificate expiry or TLS validation alerts | Prevent clients from relying on an invalid certificate where possible | Renew or replace the certificate; restart or reload the consuming service | TLS validation, service health, and alert clearance | Existing PostgreSQL coverage; assess fleet-wide coverage |
| Host disk or boot failure | Node exporter, filesystem, failed-unit, or hardware alerts | Prevent further writes to failing storage; preserve diagnostics | Rebuild or replace the host; restore state; reauthorize SOPS recipients | Boot health, SOPS decryption, monitoring, backups, and service health | Host onboarding and SOPS recovery exist; consolidate end-to-end sequence |
| Monitoring outage | External availability check, operator report, or failed monitoring unit | Avoid destructive changes based on incomplete monitoring data | Restore the affected monitoring component | Prometheus targets, alert rules, Loki ingestion, notification delivery, and dashboard access | Monitoring-of-monitoring runbook needed |

## Findings

### Missing unified severity model

The repository has monitoring and alerting controls, but there is no consistent
incident severity model that defines response expectations, ownership, and
escalation.

**Gap type:** Missing ownership and response expectations.

**Follow-up:** Add an incident severity model that maps common incident types
to critical, high, medium, and low response expectations.

### Missing cross-service secret-compromise playbook

Individual rotation runbooks exist, but a leaked secret may require a
coordinated sequence across SOPS, upstream providers, consuming services,
monitoring, and old-credential retirement.

**Gap type:** Missing recovery procedure.

**Follow-up:** Add a cross-service SOPS secret compromise response runbook.

### Missing host-compromise containment runbook

SSH, deployment, and audit controls exist, but revocation, evidence
preservation, host replacement, and post-recovery verification are not
connected in one procedure.

**Gap type:** Missing containment and recovery procedure.

**Follow-up:** Add a host compromise containment and recovery runbook.

### Missing monitoring outage runbook

Monitoring, alerting, and logging are present, but the audit should determine
whether an outage of Prometheus, Alertmanager, Loki, Grafana, or the ntfy relay
is itself detectable and recoverable.

**Gap type:** Missing detection and recovery procedure.

**Follow-up:** Add a monitoring outage response runbook and assess whether the
monitoring control plane has independent availability signals.

### Missing service-specific recovery matrix

`docs/RECOVERY.md` covers SOPS and PostgreSQL recovery, but other critical
services may lack equivalent recovery and verification steps.

**Gap type:** Documentation gap.

**Follow-up:** Inventory critical services and identify those that need a
service-specific recovery and verification runbook.

### Missing incident evidence standard

Audit logs and Loki exist, but there may not be a defined set of artifacts to
preserve during an incident.

**Gap type:** Missing evidence-preservation procedure.

**Follow-up:** Define the minimum evidence set for security and operational
incidents, including journal logs, authentication logs, active connections,
service status, configuration revisions, and relevant application logs.

## Follow-up plan

Keep follow-ups small and independently testable. Prefer documentation and
alerting changes over broad infrastructure changes.

1. Add an incident severity model.
2. Add a cross-service SOPS secret compromise response runbook.
3. Add a host compromise containment and recovery runbook.
4. Add a monitoring outage response runbook.
5. Map critical alerts to incident runbooks.
6. Inventory service-specific recovery and verification gaps.
7. Define an incident evidence-preservation standard.

## Acceptance criteria

- Every high-impact scenario has a detection path.
- Every high-impact scenario has a containment and recovery procedure.
- Every recovery procedure has explicit verification steps.
- Every gap has an owner and a concrete follow-up.
- No duplicated coverage of already-implemented backup, SOPS, Loki, or
  access-control work.
- `nix flake check --show-trace` passes after any configuration change.
