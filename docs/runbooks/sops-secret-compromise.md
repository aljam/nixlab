# Cross-service SOPS secret compromise

Use this runbook when a SOPS-protected secret may have been exposed, leaked, or used by an unauthorized party. It coordinates upstream revocation, targeted SOPS rotation, consumer recovery, verification, and retirement of the old credential.

This playbook complements `docs/runbooks/host-compromise-recovery.md`. Use that runbook instead when the primary concern is a compromised host, SSH identity, or deployment identity.

## Scope

Use this playbook for a secret stored in one of the following SOPS trust boundaries:

| SOPS file | Typical consumers | Recovery emphasis |
|---|---|---|
| `secrets/common.yaml` | Shared user and login secrets | Rotate the affected credential and update authorized consumers |
| `secrets/database.yaml` | PostgreSQL and pgAdmin on `r820` | Rotate the database credential, reload or redeploy consumers, and verify connectivity and TLS |
| `secrets/matrix.yaml` | Matrix, MatrixRTC, LiveKit, and pfSense CA secrets on `r730xd` and `r820` | Rotate the affected provider credential and validate service authentication |
| `secrets/vaultwarden.yaml` | Vaultwarden on `r730xd` and `r820` | Rotate the affected provider credential and verify service health |
| `secrets/monitoring.yaml` | Grafana and alerting on `r730`, `r730xd`, and `r820` | Preserve alerting continuity while rotating credentials |
| `secrets/media.yaml` | Radarr, Sonarr, and Recyclarr on `r730xd` | Rotate upstream API credentials and validate integrations |
| `secrets/nas.yaml` | NAS credentials on `navi` and `oryx` | Rotate the NAS credential and verify mounts |

SOPS files are service- and trust-boundary-scoped. Do not assume that every host is affected; use `.sops.yaml` and the secret inventory to determine the exact recipient and consumer set.

## Initial response

1. Declare an incident using `docs/runbooks/incident-severity.md`.
2. Identify the exposed secret, its SOPS file, detection source, and suspected exposure window.
3. Identify every host and service authorized to consume the secret.
4. Determine whether the underlying upstream credential must be revoked, not merely re-encrypted.
5. Freeze deployments if unauthorized configuration or deployment activity is suspected.
6. Assign owners for upstream revocation, SOPS rotation, consumer recovery, verification, and incident records.

Preserve evidence before destructive recovery. Retain authentication logs, application logs, relevant audit records, configuration revisions, and the time at which the exposure was detected.

## Contain the credential

1. Revoke, disable, or invalidate the exposed credential at its upstream provider.
2. If the provider does not support immediate revocation, restrict its scope or permissions as much as possible.
3. Stop using the exposed credential for new authentications where operationally possible.
4. Do not paste, commit, send, or store the exposed value in additional systems.
5. If compromise of a host is suspected, follow `docs/runbooks/host-compromise-recovery.md` before relying on that host.

Revoking the upstream credential is the primary containment action. Re-encrypting a SOPS file alone does not invalidate a credential that has already been exposed.

## Rotate the secret

1. Generate a replacement credential with the minimum required scope and lifetime.
2. Update the affected SOPS file using `sops`.
3. Update the secret inventory rotation date.
4. Update the consuming service configuration only if the secret name, format, or associated configuration changes.
5. Do not add recipients or grant access to unrelated hosts.
6. Run `nix flake check --show-trace` before committing configuration changes.

A SOPS recipient change and a secret-value rotation are distinct actions:

- `sops updatekeys` changes who can decrypt the SOPS file.
- Rotating the underlying credential changes the value used by the consuming service.

A compromise may require both actions, but neither automatically performs the other.

## Recover consumers

1. Deploy the configuration change to every host authorized for the affected SOPS file.
2. Restart or reload only the services that consume the rotated secret, following the service-specific procedure where one exists.
3. Confirm that the service can decrypt its secret and authenticate with the replacement credential.
4. Do not deploy the replacement credential to hosts outside the documented recipient set.

For recipient changes caused by a rebuilt or replaced host, follow the recipient-change procedure in `docs/SECRETS.md` and the SOPS recovery procedure in `docs/RECOVERY.md`.

## Verify recovery

Before closing the incident, verify:

- The old credential is rejected by its upstream provider.
- The replacement credential is present only in the intended SOPS file and recipient set.
- Every authorized consumer can decrypt its secret.
- Every affected service is healthy and authenticates successfully.
- Relevant upstream integrations function correctly.
- Monitoring, alerting, and notification delivery remain operational.
- Relevant alerts are resolved only after their underlying conditions are verified.
- No unauthorized configuration drift remains.

For PostgreSQL, verify TCP reachability and TLS with `sslmode=verify-full`; for monitoring, confirm that Prometheus targets, Alertmanager alerts, Loki ingestion, and notification delivery remain functional.

## Retire and record

1. Confirm that the old credential can no longer authenticate.
2. Remove any temporary access, exception, or emergency permission created during response.
3. Record the incident timeline, exposed secret, affected hosts and services, revocation and rotation times, verification results, and retained evidence.
4. Create follow-up work for the exposure source, detection gap, or recovery friction.

Do not record the exposed or replacement secret value in the incident record. Record identifiers, rotation dates, and verification outcomes instead.

## Related documentation

- `docs/runbooks/host-compromise-recovery.md`
- `docs/runbooks/incident-severity.md`
- `docs/SECRETS.md`
- `docs/RECOVERY.md`
- `docs/audits/incident-response-recovery.md`
