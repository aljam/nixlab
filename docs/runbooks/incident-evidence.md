# Incident evidence preservation standard

Use this standard when responding to an operational or security incident. It defines the minimum evidence to preserve, scenario-specific evidence, handling rules, retention expectations, and a simple incident-record template.

This standard supports `docs/runbooks/incident-severity.md`. It does not replace the applicable containment or recovery runbook.

## Principles

1. Preserve evidence before taking disruptive action.
2. Use the least disruptive effective containment action.
3. Store evidence outside the potentially compromised host.
4. Record what was collected, when, from where, how, and where it is stored.
5. Do not copy, transmit, or retain secret values unnecessarily.
6. Retain evidence according to the incident’s final severity and any external requirement.

If immediate containment requires changing a system before evidence can be collected, preserve whatever evidence is still available and record the reason for the exception.

## Minimum evidence

For every incident, preserve:

- Detection time, detection source, and initial severity.
- Affected host, service, credential, secret, or data scope.
- Relevant system journal entries.
- Relevant application, authentication, and audit logs.
- Service status and recent restart or failure history.
- Configuration revision and recent configuration changes.
- Monitoring alerts, dashboard state, and notification delivery evidence where available.
- A timeline of detection, containment, recovery, and verification actions.

Record the collection time, source host, collector or command, and storage location for every artifact.

## Scenario-specific evidence

| Incident | Additional evidence to preserve |
|---|---|
| Host compromise | SSH authentication and authorization logs; active connections; listening services; running processes; loaded systemd units; suspicious files; deployed configuration revision; persistence indicators. |
| SSH or deploy identity compromise | Affected key identifiers and fingerprints; authorized-key state; SSH authentication logs; deployment history; audit logs; forced-command and sudo policy state. |
| SOPS secret exposure | Secret identifier; SOPS file; recipient set; exposure source and window; upstream revocation and rotation times; consumer recovery evidence; verification results. Do not retain the exposed or replacement secret value. |
| Public-service compromise | Reverse-proxy access and error logs; application logs; authentication logs; TLS certificate state; endpoint probe results; deployed configuration revision. |
| Database compromise or corruption | PostgreSQL logs; role, grant, and session state; backup age and integrity; restore evidence; data-integrity checks; application connectivity results. |
| Backup failure | Backup unit journal; repository availability; lock state; last-success timestamp; retention and recovery-point checks; restore or integrity-test results. |
| Monitoring outage | Component journals; Prometheus target, rule, and alert state; Alertmanager routing logs; ntfy delivery logs; Loki ingestion and query errors; Grafana data-source errors; drift-monitoring results. |
| Configuration drift | Expected and actual configuration revisions; drift-monitoring output; firewall and listener state; deployment history; authorization evidence; relevant audit logs. |

## Evidence handling

- Collect evidence into an access-controlled location that is not controlled by the potentially compromised host.
- Prefer read-only copies or exports over modifying original logs and state.
- Record file names, collection commands, timestamps, and integrity hashes where practical.
- Limit access to operators directly involved in the response.
- Do not paste secret values, private keys, recovery codes, or full credential material into incident records, chat, tickets, or documentation.
- Record secret identifiers, key fingerprints, SOPS file names, rotation dates, and verification outcomes instead.
- Do not delete original evidence when an incident is closed; archive it according to the retention policy.

## Retention

| Incident severity | Minimum retention |
|---|---:|
| Critical | 90 days after closure |
| High | 90 days after closure |
| Medium | 30 days after closure |
| Low | 30 days after closure |

Retain evidence longer when required by an upstream provider, legal obligation, insurance requirement, law-enforcement request, or active investigation. Record any extension and its reason.

## Incident record template

```markdown
# Incident record

- Incident ID:
- Detection time:
- Detection source:
- Initial severity:
- Final severity:
- Status:
- Affected host(s):
- Affected service(s):
- Affected credential(s) or secret(s):
- Affected data or users:

## Timeline

- Detection:
- Containment:
- Recovery:
- Verification:
- Closure:

## Evidence

| Artifact | Source host | Collected at | Collection method | Storage location | Integrity check |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

## Containment and recovery

- Actions taken:
- Credentials or secrets rotated:
- Temporary controls retained:
- Recovery point used:

## Verification

- Functional checks:
- Monitoring checks:
- Alert status:
- Backup status:
- Access-control status:

## Root cause and follow-up

- Root cause or open question:
- Preventive actions:
- Detection improvements:
- Recovery improvements:
```

## Related documentation

- `docs/runbooks/incident-severity.md`
- `docs/runbooks/host-compromise-recovery.md`
- `docs/runbooks/sops-secret-compromise.md`
- `docs/runbooks/monitoring-outage.md`
- `docs/audits/incident-response-recovery.md`
