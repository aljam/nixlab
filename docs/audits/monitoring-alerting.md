# Monitoring and alerting coverage audit

Use this audit to periodically verify that monitoring detects material service, security, capacity, and recovery failures and that alerts reach an accountable owner.

This audit must not expose secrets, tokens, passwords, private keys, or sensitive service data. Record alert names, severity, routing outcomes, evidence references, and remediation actions only.

## Audit objective

For every production service and shared platform component, verify that:

- Service availability and health are monitored.
- Resource exhaustion and capacity risks are detected before they cause an outage.
- Backup, recovery, certificate, authentication, and security failures generate actionable alerts.
- Alerts have an owner, severity, runbook, and escalation path.
- Alert routing is tested and reaches the intended on-call or operational channel.
- Alert noise is reviewed and reduced without suppressing material failures.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Service health and alert coverage | Monthly | Service owner | Alert inventory, coverage result, and exceptions |
| Alert routing and escalation | Monthly | Operations owner | Test result, delivery channel, and acknowledgement status |
| Certificate expiry review | Monthly | Platform owner | Certificate names, expiry dates, and alert status |
| Capacity and resource review | Monthly | Platform owner | Utilization, thresholds, and capacity risks |
| Backup and recovery alert review | Monthly | Backup and recovery owner | Alert coverage, test result, and remediation status |
| Security alert review | Quarterly | Security owner | Alert coverage, test result, and remediation status |
| Full audit review | Quarterly | Service, platform, and security owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every production service and shared platform component.
- [ ] Identify the monitoring system and alert-routing channels.
- [ ] Identify the accountable owner for each service and alert.
- [ ] Identify the expected severity and escalation path for each alert class.
- [ ] Confirm the audit environment cannot modify production monitoring configuration or suppress production alerts.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm recent incidents and alerts are available for review.

## Service health

For each production service:

- [ ] Confirm the service process or container is monitored.
- [ ] Confirm service availability is monitored from an appropriate internal or external perspective.
- [ ] Confirm health checks validate functional readiness, not only process existence.
- [ ] Confirm dependency health is monitored where applicable.
- [ ] Confirm database, cache, message-queue, and storage dependencies are monitored.
- [ ] Confirm service-specific error rates, latency, and saturation metrics are monitored where applicable.
- [ ] Confirm failed health checks generate an alert.
- [ ] Confirm prolonged service unavailability generates an alert.
- [ ] Confirm the alert has an owner, severity, runbook, and escalation path.

## Resource capacity

For each host, container, database, and storage volume:

- [ ] Confirm CPU saturation is monitored.
- [ ] Confirm memory pressure or exhaustion is monitored.
- [ ] Confirm disk usage and growth are monitored.
- [ ] Confirm inode exhaustion is monitored where applicable.
- [ ] Confirm database connection saturation is monitored.
- [ ] Confirm storage capacity is monitored for databases, media stores, logs, and backup staging areas.
- [ ] Confirm alert thresholds provide actionable lead time before service impact.
- [ ] Confirm capacity alerts have an owner and remediation runbook.
- [ ] Confirm recurring capacity risks are tracked as capacity-planning actions.

## Certificates and TLS

For every public and internal TLS endpoint:

- [ ] Identify the certificate, hostname, issuer, and expiry date.
- [ ] Confirm certificate expiry is monitored.
- [ ] Confirm alerts fire before expiration with sufficient renewal lead time.
- [ ] Confirm certificate renewal succeeds or generates an actionable failure alert.
- [ ] Confirm certificate deployment is monitored where applicable.
- [ ] Confirm TLS configuration errors generate an alert.
- [ ] Confirm expired or misconfigured certificates are treated as service-impacting incidents.
- [ ] Record certificate names and expiry dates without exposing private keys or secrets.

## Authentication and access

For each authentication and identity dependency:

- [ ] Confirm authentication-service availability is monitored.
- [ ] Confirm authentication failure rates are monitored.
- [ ] Confirm SSO, LDAP, OAuth, OIDC, or identity-provider failures generate an alert.
- [ ] Confirm credential or secret-retrieval failures generate an alert.
- [ ] Confirm suspicious authentication activity is monitored where applicable.
- [ ] Confirm access-control or authorization failures generate an alert where material.
- [ ] Confirm authentication alerts have an owner, severity, and response procedure.
- [ ] Confirm alerts do not expose credentials, tokens, session identifiers, or personal data.

## Backup and recovery

For each backup job and recovery dependency:

- [ ] Confirm backup-job failure is monitored.
- [ ] Confirm missed, stale, or incomplete backups are monitored.
- [ ] Confirm backup-repository access failure is monitored.
- [ ] Confirm repository-integrity failure is monitored.
- [ ] Confirm retention-job failure is monitored.
- [ ] Confirm backup staging and repository capacity are monitored.
- [ ] Confirm recovery-critical service failures are monitored.
- [ ] Confirm backup and recovery alerts have an owner, severity, and remediation runbook.
- [ ] Confirm restore drills and recovery tests are tracked or scheduled.

## Security events

For each security-relevant control:

- [ ] Confirm authentication and authorization failures are monitored where applicable.
- [ ] Confirm firewall, WAF, or reverse-proxy security events are monitored where applicable.
- [ ] Confirm certificate and TLS failures are monitored.
- [ ] Confirm secret-retrieval or secret-manager failures are monitored.
- [ ] Confirm privileged-access or administrative activity is monitored where applicable.
- [ ] Confirm security alerts have an owner, severity, and response procedure.
- [ ] Confirm security alerts do not expose secrets, tokens, or sensitive user data.
- [ ] Confirm security incidents are linked to the incident-response and evidence-preservation procedures.

## Alert routing

For each alert class:

- [ ] Identify the intended delivery channel.
- [ ] Confirm the channel is reachable and monitored.
- [ ] Confirm the alert reaches the accountable owner or on-call rotation.
- [ ] Confirm escalation occurs when an alert is not acknowledged within the expected period.
- [ ] Confirm alert severity matches the potential service, security, or recovery impact.
- [ ] Confirm alert descriptions include actionable context without exposing secrets.
- [ ] Confirm alert runbooks are linked or discoverable.
- [ ] Confirm alert acknowledgements and resolutions are recorded.
- [ ] Test at least one representative alert delivery path during the audit.

## Alert quality

- [ ] Identify alerts that fired repeatedly without actionable follow-up.
- [ ] Identify alerts that lack an owner, severity, runbook, or escalation path.
- [ ] Identify alerts that are too broad, too noisy, or duplicate another alert.
- [ ] Identify material failure modes that do not generate an alert.
- [ ] Confirm noisy alerts have a documented tuning or suppression plan.
- [ ] Confirm suppressions have an owner, justification, and expiration date.
- [ ] Confirm alert changes are reviewed and tested before deployment.
- [ ] Confirm alert coverage gaps are tracked as findings.

## Findings and remediation

Classify each finding as:

- **Critical:** A material service, security, capacity, backup, or recovery failure is not detected or cannot reach an accountable owner.
- **High:** Alerting coverage, routing, severity, or escalation creates a material operational or security risk.
- **Medium:** A control is incomplete, undocumented, noisy, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected service, component, alert, and control.
- [ ] Record the severity and potential impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as operational or security incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Every production service has health and availability monitoring.
- Capacity, certificate, authentication, backup, and security failures are detected where applicable.
- Alerts route to an accountable owner or on-call rotation.
- Alert severity, runbooks, and escalation paths are defined.
- Alert routing is tested for at least one representative alert.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/restic-restore-drill.md`
- `docs/runbooks/postgresql-restore-drill.md`
- `docs/runbooks/matrix-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/backup-integrity.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
- `docs/audits/incident-response-recovery.md`
