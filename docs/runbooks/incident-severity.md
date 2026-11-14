# Incident severity and response expectations

## Purpose

This runbook defines a consistent way to classify and respond to operational
and security incidents in the homelab.

Severity is based on impact, not on the tool that detected the problem. An
alert may be informational, but the underlying incident can still be critical
if it affects confidentiality, integrity, availability, or recoverability.

## Severity levels

| Severity | Definition | Initial response | Recovery and verification |
|---|---|---|---|
| Critical | Active compromise, unavailable critical service, confirmed data loss, or a backup failure with no known-good recovery point | Respond immediately; preserve evidence; contain before making broad changes | Restore or redeploy using the applicable recovery procedure; verify service health, access controls, monitoring, and backups |
| High | Limited-scope secret exposure, certificate renewal failure, monitoring outage, or repeated backup failure | Respond the same day; determine blast radius and recovery path | Rotate or repair the affected component; verify the specific recovery path and alerts |
| Medium | Degraded redundancy, noncritical service outage, or configuration drift without confirmed impact | Investigate and schedule remediation | Correct the configuration or service; verify the intended behavior and monitoring |
| Low | Cosmetic issue, informational alert, or documentation gap | Track and resolve during normal maintenance | Apply the fix; verify that the issue does not recur |

## Severity assignment

Assign the highest severity that applies. If impact is uncertain, treat the
incident as one level higher until triage establishes the actual scope.

| Incident type | Initial severity | Notes |
|---|---|---|
| Confirmed host compromise | Critical | Preserve evidence before rebooting or rebuilding. |
| Compromised SSH key or deploy identity | Critical | Revoke access and preserve evidence before recovery. |
| Publicly exposed secret | Critical | Revoke the upstream credential where possible, then rotate the SOPS secret. |
| Critical public service unavailable | Critical | Restore service availability and determine whether compromise occurred. |
| Confirmed data loss without a known-good recovery point | Critical | Stop destructive actions and preserve available evidence. |
| Backup failure with no verified recovery point | Critical | Treat as a recoverability incident, not merely a failed job. |
| Database compromise or corruption | Critical or High | Use Critical when data loss or unauthorized access is confirmed. |
| Certificate renewal failure | High | Prevent service disruption and verify the replacement certificate. |
| Monitoring or alerting outage | High | Determine whether the outage masks other failures. |
| Repeated backup failures | High | Identify the underlying cause before the backup becomes stale. |
| Configuration drift | Medium or High | Use High when unauthorized change or compromise is suspected. |
| Noncritical service outage | Medium | Restore the service and identify the root cause. |
| Reduced redundancy | Medium | Restore redundancy before another failure creates an outage. |
| Documentation or alert-quality gap | Low | Track and resolve during normal maintenance. |

## Response workflow

For every incident:

1. Record the detection time, signal, affected host or service, and initial severity.
2. Determine the blast radius: affected hosts, services, credentials, data, and users.
3. Preserve relevant evidence before taking disruptive action.
4. Contain the incident using the least disruptive effective action.
5. Follow the applicable recovery runbook.
6. Verify recovery with service health, monitoring, logs, and functional checks.
7. Close the incident only after alerts clear and recovery is verified.
8. Create follow-up work for root cause, missing detection, or missing recovery coverage.

## Containment principles

- Prefer reversible containment actions.
- Do not destroy evidence or state before preserving it.
- Do not rotate every credential in response to an unconfirmed incident.
- Do not deploy broad configuration changes while the cause is unknown.
- Do not assume a monitoring outage means the monitored services are healthy.
- Do not return a host to service until its access, secrets, monitoring, backups, and critical services are verified.

## Verification

Recovery is not complete until:

- The triggering alert has cleared or has been explicitly explained.
- The affected service is healthy and functionally verified.
- Relevant logs show the expected recovery behavior.
- Credentials, access controls, and secrets are in the intended state.
- Monitoring, alerting, and backup coverage are operational.
- Any temporary containment measure has been removed or explicitly retained with a follow-up.

## Follow-up

Every Critical or High incident should produce:

- A timeline of detection, containment, recovery, and verification.
- The root cause or the open question that prevented identifying it.
- Evidence retained for review.
- Configuration, alerting, documentation, or runbook changes needed to prevent recurrence.

## Related documentation

- `docs/audits/incident-response-recovery.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
- `docs/SECRETS.md`
- `docs/runbooks/`
