# Access control and secrets audit

Use this audit to periodically verify that human and service access follows least privilege, secrets are stored and rotated safely, and break-glass access remains available without becoming an unmanaged privilege.

This audit must not expose secrets, tokens, passwords, private keys, session identifiers, or personal data. Record identities, roles, scopes, access decisions, rotation status, findings, and remediation actions only.

## Audit objective

For every production service, host, repository, and administrative interface, verify that:

- Access is limited to approved identities and required permissions.
- Administrative and break-glass access is controlled, auditable, and recoverable.
- Secrets are stored in the approved secret manager and are not embedded in code, configuration, logs, or documentation.
- Credentials are rotated or replaced according to policy.
- Service identities use least privilege and are separated from human accounts.
- Access changes are reviewed, approved, and recorded.
- Excessive, unused, or unowned access is identified and remediated.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Human access review | Quarterly | Security owner | Identity list, roles, access decisions, and exceptions |
| Service identity review | Quarterly | Service owner | Identity list, permissions, and ownership |
| Secret inventory review | Quarterly | Security owner | Secret references, owners, rotation status, and exceptions |
| Credential exposure review | Quarterly | Security owner | Scan scope, findings, and remediation status |
| Break-glass access review | Quarterly | Security owner | Break-glass procedure, access evidence, and test result |
| SSH and host access review | Quarterly | Platform owner | Access list, key status, and exceptions |
| Full audit review | Quarterly | Security, platform, and service owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every production host, service, repository, and administrative interface.
- [ ] Identify every human identity with production access.
- [ ] Identify every service identity, API key, token, and credential.
- [ ] Identify the approved secret manager and its secret references.
- [ ] Identify the break-glass access procedure and its approval path.
- [ ] Confirm the audit environment cannot modify production access controls or expose secrets.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm recent access changes, incidents, and credential rotations are available for review.

## Human access

For each human identity with production access:

- [ ] Confirm the identity has a documented owner and business justification.
- [ ] Confirm the identity uses MFA or an equivalent strong-authentication control.
- [ ] Confirm access is limited to the minimum roles and permissions required.
- [ ] Confirm administrative access is separated from routine operational access where possible.
- [ ] Confirm access is revoked promptly when no longer required.
- [ ] Confirm access changes are reviewed and approved.
- [ ] Confirm unused or dormant accounts are identified and remediated.
- [ ] Confirm shared accounts are not used for production administration.
- [ ] Confirm access reviews identify excessive or unowned permissions.

## Service identities

For each service identity, API key, token, or credential:

- [ ] Confirm the identity has a documented owner and purpose.
- [ ] Confirm the identity uses the minimum permissions required.
- [ ] Confirm service identities are separated from human accounts.
- [ ] Confirm credentials are stored in the approved secret manager.
- [ ] Confirm credentials are not embedded in source code, Nix configuration, scripts, logs, or documentation.
- [ ] Confirm credentials are not shared across unrelated services.
- [ ] Confirm credential scope is limited to the required resource and operation.
- [ ] Confirm unused or obsolete credentials are identified and revoked.
- [ ] Confirm credential rotation or replacement plans exist.
- [ ] Confirm credential creation, rotation, and revocation are auditable.

## Secret storage

For each secret reference:

- [ ] Confirm the secret is stored in the approved secret manager.
- [ ] Confirm the secret has a documented owner and purpose.
- [ ] Confirm the secret reference is documented without exposing its value.
- [ ] Confirm the secret is not committed to the Git repository.
- [ ] Confirm the secret is not present in Nix store paths, build outputs, logs, or incident records.
- [ ] Confirm the secret is not exposed through environment dumps, process listings, or diagnostic output.
- [ ] Confirm access to the secret is limited to approved identities and services.
- [ ] Confirm secret access is logged or auditable where supported.
- [ ] Confirm secret rotation status and next rotation date are recorded.
- [ ] Confirm compromised or exposed secrets are revoked and replaced promptly.

## Credential exposure

- [ ] Scan the repository and configuration for committed credentials, tokens, private keys, and connection strings.
- [ ] Confirm secret-scanning controls are active where available.
- [ ] Confirm historical Git history is reviewed for exposed secrets when a potential exposure is identified.
- [ ] Confirm exposed credentials are revoked, rotated, or replaced.
- [ ] Confirm affected systems and downstream consumers are identified.
- [ ] Confirm incident records do not contain secret values or sensitive connection strings.
- [ ] Confirm remediation is verified before the finding is closed.
- [ ] Confirm repeat exposure risks are addressed through developer guidance and repository controls.

## Break-glass access

- [ ] Confirm a documented break-glass procedure exists.
- [ ] Confirm break-glass credentials are stored securely and are not embedded in documentation or code.
- [ ] Confirm break-glass access requires approval or an auditable activation step.
- [ ] Confirm break-glass access is time-limited or revoked after use.
- [ ] Confirm break-glass use generates an alert or incident record.
- [ ] Confirm break-glass access is tested without exposing credentials.
- [ ] Confirm break-glass access does not bypass MFA or approval controls unnecessarily.
- [ ] Confirm break-glass procedures are linked to incident response and recovery documentation.

## SSH and host access

For each production host:

- [ ] Confirm SSH access is limited to approved identities and networks.
- [ ] Confirm password authentication is disabled where supported.
- [ ] Confirm root login is disabled or tightly controlled.
- [ ] Confirm SSH keys are documented, owned, and rotated or replaced when necessary.
- [ ] Confirm unused SSH keys and accounts are removed.
- [ ] Confirm administrative access uses least privilege.
- [ ] Confirm SSH access is logged or auditable where supported.
- [ ] Confirm host-access changes are reviewed and approved.
- [ ] Confirm emergency host access follows the break-glass procedure.

## Access logging and review

- [ ] Confirm authentication successes and failures are logged where supported.
- [ ] Confirm administrative actions are logged or auditable where supported.
- [ ] Confirm secret access is logged or auditable where supported.
- [ ] Confirm logs do not contain secrets, tokens, private keys, or sensitive user data.
- [ ] Confirm logs are retained according to the incident-evidence and retention policy.
- [ ] Confirm access reviews identify anomalous or unexpected access.
- [ ] Confirm access-review findings have an owner and remediation plan.

## Findings and remediation

Classify each finding as:

- **Critical:** A secret is exposed, an unmanaged administrative path exists, or production access cannot be revoked.
- **High:** Access, secret storage, rotation, or break-glass controls create a material security or recovery risk.
- **Medium:** A control is incomplete, undocumented, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected identity, service, host, secret reference, or control.
- [ ] Record the severity and potential impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as security incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Human and service access follows least privilege.
- Administrative and break-glass access is controlled and auditable.
- Secrets are stored in the approved secret manager and are not exposed in code, configuration, logs, or documentation.
- Credentials have owners, rotation plans, and revocation paths.
- SSH and host access are limited to approved identities.
- Access changes are reviewed and recorded.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/backup-integrity.md`
- `docs/audits/monitoring-alerting.md`
- `docs/RECOVERY.md`
- `docs/BACKUPS.md`
- `docs/audits/incident-response-recovery.md`
