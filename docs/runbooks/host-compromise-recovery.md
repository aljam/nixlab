# Host compromise recovery

Use this runbook when there is credible evidence that a managed host, its SSH host identity, a deployment identity, or a host-local secret has been compromised.

This procedure connects existing controls; it does not replace the deployment authorization boundary, SOPS recovery procedure, or incident severity model.

## Scope

Use this runbook for:

- A compromised interactive SSH key or deployment key.
- Unauthorized configuration, package, service, or deployment activity.
- Evidence of attacker-controlled processes, persistence, or lateral movement.
- A host whose SSH host key, SOPS age identity, or local secret material may be exposed.

Do not use this runbook for a routine service failure without evidence of compromise. Follow the relevant service recovery procedure instead.

## Initial response

1. Declare an incident using `docs/runbooks/incident-severity.md`.
2. Identify the affected host, suspected credential, affected services, and time window.
3. Determine whether deployment authorization should be frozen. If unauthorized deployment activity is suspected, stop using the deployment path until the affected identity and host are contained.
4. Assign an owner for containment, evidence preservation, recovery, and communication.

Do not reboot, reinstall, or otherwise alter the host before preserving the evidence needed for investigation, unless immediate containment requires it.

## Preserve evidence

Before revoking access or rebuilding, retain:

- System journal entries for the suspected period.
- SSH authentication and authorization logs.
- Active network connections and listening services.
- Running processes and loaded systemd units.
- Recent configuration changes and the deployed configuration revision.
- Relevant application, authentication, and audit logs.
- Copies of suspicious files or artifacts in a secure, access-controlled location.

Record the collection time, host, collector or command, and storage location for each artifact. Preserve evidence in a location that is not controlled by the potentially compromised host.

## Contain access

1. Revoke or disable the compromised interactive SSH key.
2. Revoke or rotate the compromised deployment key if it is affected.
3. Remove the compromised key from the authorized user or deploy identity.
4. Disable deployment authorization for the affected host if unauthorized deployment is confirmed or cannot be ruled out.
5. Revoke or rotate any exposed upstream credential associated with services on the host.
6. Restrict network access to the host when necessary to prevent further lateral movement or data exfiltration.

Treat a compromised SSH host key as compromised: do not simply redeploy it unchanged.

## Rotate secrets

1. Identify every SOPS secret authorized to the affected host using the secret inventory and `.sops.yaml` recipient policy.
2. Rotate any secret whose value may have been exposed, including upstream provider credentials, database credentials, API tokens, and service passwords.
3. Update the consuming service configuration only when the secret name or format changes.
4. Update the secret inventory rotation date.
5. Follow the recipient-change procedure in `docs/SECRETS.md` when the host’s age identity changes.

A recipient change alone does not rotate a secret’s value. Rotate the underlying credential when exposure is suspected.

## Recover the host

1. Rebuild or replace the host from a known-good revision on `main`.
2. Preserve the SSH Ed25519 host key only when its integrity is confirmed; otherwise generate and deploy a replacement host key.
3. Update the host’s SOPS age recipient in `.sops.yaml`.
4. Remove the retired host recipient.
5. Re-encrypt every secret authorized for the replacement host with `sops updatekeys`.
6. Run the SOPS recovery drill before relying on the host:

   ```console
   bash scripts/sops-recovery-drill.sh --host <host>
   ```

7. Confirm that the host can decrypt only its authorized secrets.
8. Deploy the rebuilt host only after the drill passes.

For detailed SOPS recovery steps, see `docs/RECOVERY.md` and `docs/SECRETS.md`.

## Verify recovery

Before returning the host to normal operation, verify:

- The host is running the intended configuration revision from `main`.
- SSH remains key-only and the deploy identity permits only the authorized `deploy-rebuild switch <full 40-character commit hash>` command.
- The affected deploy identity can no longer authenticate with revoked credentials.
- SOPS decryption succeeds only for secrets authorized to the host.
- Critical services are healthy and their expected listeners are present.
- Prometheus targets, Alertmanager alerts, Loki ingestion, and notification delivery are functioning.
- No unauthorized configuration drift remains.
- Backups and monitoring data are being produced again.

Do not clear an alert until its underlying condition has been verified as resolved.

## Record and follow up

Record:

- Incident timeline and detection source.
- Affected host, identities, credentials, secrets, and services.
- Containment and recovery actions, including times.
- Evidence retained and its storage location.
- Root cause, if known.
- Follow-up actions, including control improvements, credential rotations, and documentation updates.

Create follow-up work for any gap that allowed the compromise, delayed detection, or complicated recovery.

## Related documentation

- `docs/runbooks/incident-severity.md`
- `docs/RECOVERY.md`
- `docs/SECRETS.md`
- `docs/security/deploy-authorization.md`
- `docs/security/ssh-key-audit.md`
- `docs/audits/incident-response-recovery.md`
