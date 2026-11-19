# Host hardening and patch audit

Use this audit to periodically verify that NixOS hosts run supported, patched software, follow the intended hardening baseline, and do not drift from the declared configuration.

This audit must not expose secrets, private keys, tokens, passwords, or sensitive host data. Record host names, NixOS generations, package versions, vulnerability references, findings, and remediation actions only.

## Audit objective

For every production host, verify that:

- The host runs a supported NixOS generation.
- The deployed configuration matches the declared repository configuration.
- Security updates and vulnerable packages are identified and remediated.
- SSH, service accounts, file permissions, and logging follow the intended hardening baseline.
- Unused services, packages, and accounts are removed.
- Configuration drift, failed activations, and security findings have an owner and remediation plan.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| NixOS generation and drift review | Weekly | Platform owner | Current generation, declared revision, and drift result |
| Security update review | Weekly | Platform owner | Package versions, vulnerability references, and remediation status |
| SSH and account review | Monthly | Security owner | Account inventory, SSH configuration, and exceptions |
| File permission and service review | Monthly | Platform owner | Permission findings, service inventory, and exceptions |
| Logging and audit review | Monthly | Security owner | Log sources, retention status, and exceptions |
| Full audit review | Quarterly | Platform and security owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every production host and its role.
- [ ] Identify the declared NixOS configuration and flake revision for each host.
- [ ] Identify the current deployed NixOS generation.
- [ ] Identify the approved package set and vulnerability-scanning method.
- [ ] Identify the SSH, service-account, and logging baseline.
- [ ] Confirm the audit environment cannot modify production hosts or expose secrets.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm recent deployments, configuration changes, and security advisories are available for review.

## NixOS generation and drift

For each production host:

- [ ] Identify the current NixOS generation and its build time.
- [ ] Identify the declared configuration revision or flake input used to build it.
- [ ] Confirm the current generation was built from the intended repository revision.
- [ ] Confirm the deployed configuration matches the declared configuration.
- [ ] Confirm no untracked configuration files, manual edits, or out-of-band changes are present.
- [ ] Confirm the previous generation is retained for rollback where appropriate.
- [ ] Confirm failed activations or deployment errors are investigated.
- [ ] Confirm stale generations are cleaned according to the approved retention policy.
- [ ] Confirm configuration drift findings have an owner and remediation plan.

## Package and kernel updates

For each production host:

- [ ] Identify the NixOS version and kernel version.
- [ ] Identify the package versions for security-relevant software.
- [ ] Identify known vulnerabilities affecting installed packages.
- [ ] Confirm vulnerability findings are triaged with severity, exploitability, and service impact.
- [ ] Confirm security updates are applied through a reviewed NixOS configuration change.
- [ ] Confirm critical vulnerabilities have an owner and remediation deadline.
- [ ] Confirm packages that cannot be updated have a documented exception, compensating control, and review date.
- [ ] Confirm kernel or package updates are tested before production deployment where feasible.
- [ ] Confirm update rollbacks are available through prior NixOS generations.
- [ ] Confirm update outcomes and vulnerability status are recorded.

## SSH hardening

For each production host:

- [ ] Confirm SSH access is limited to approved identities and networks.
- [ ] Confirm password authentication is disabled where supported.
- [ ] Confirm root login is disabled or tightly controlled.
- [ ] Confirm SSH protocol version 2 is enforced.
- [ ] Confirm approved key types and algorithms are used.
- [ ] Confirm deprecated or weak algorithms are disabled where supported.
- [ ] Confirm SSH keys are owned, documented, and rotated or replaced when necessary.
- [ ] Confirm unused SSH keys and accounts are removed.
- [ ] Confirm SSH access is logged or auditable where supported.
- [ ] Confirm emergency access follows the break-glass procedure.

## Service accounts

For each production service:

- [ ] Confirm the service runs under a dedicated, least-privileged system account where supported.
- [ ] Confirm service accounts do not have unnecessary shell access.
- [ ] Confirm service accounts do not reuse human credentials.
- [ ] Confirm service accounts cannot access unrelated secrets or resources.
- [ ] Confirm service accounts are documented with an owner and purpose.
- [ ] Confirm unused service accounts are disabled or removed.
- [ ] Confirm service-account changes are reviewed and recorded.
- [ ] Confirm privileged operations use the minimum required authorization.

## File permissions

For each production host:

- [ ] Confirm configuration files do not expose secrets or private keys.
- [ ] Confirm secret files use restrictive ownership and permissions.
- [ ] Confirm service state directories use appropriate ownership and permissions.
- [ ] Confirm world-writable files and directories are investigated and remediated.
- [ ] Confirm SUID and SGID binaries are reviewed where applicable.
- [ ] Confirm sensitive logs do not contain secrets, tokens, private keys, or sensitive user data.
- [ ] Confirm permission changes are reviewed and recorded.
- [ ] Confirm permission findings have an owner and remediation plan.

## Logging and auditing

For each production host:

- [ ] Confirm system logs are collected or retained according to policy.
- [ ] Confirm authentication successes and failures are logged where supported.
- [ ] Confirm administrative actions are logged or auditable where supported.
- [ ] Confirm service failures and security-relevant events are logged.
- [ ] Confirm logs do not contain secrets, tokens, private keys, or sensitive user data.
- [ ] Confirm log retention meets the incident-evidence and retention policy.
- [ ] Confirm log forwarding or retention failures generate an alert where supported.
- [ ] Confirm audit findings have an owner and remediation plan.

## Configuration hardening

For each production host:

- [ ] Confirm unnecessary packages and services are removed.
- [ ] Confirm unused network listeners are disabled.
- [ ] Confirm firewall rules follow the network-exposure audit baseline.
- [ ] Confirm automatic security updates or update procedures are documented.
- [ ] Confirm time synchronization is configured.
- [ ] Confirm host clocks are accurate.
- [ ] Confirm resource limits and capacity monitoring are configured where applicable.
- [ ] Confirm host hardening exceptions have an owner, justification, and review date.

## Findings and remediation

Classify each finding as:

- **Critical:** A remotely exploitable vulnerability, exposed secret, unmanaged administrative path, or configuration drift creates immediate production risk.
- **High:** Patching, SSH, service-account, permission, logging, or drift controls create a material security or availability risk.
- **Medium:** A control is incomplete, undocumented, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected host, generation, package, service, account, or control.
- [ ] Record the severity and potential impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as security incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Every production host runs a supported, declared NixOS generation.
- Configuration drift is absent or has an owner and remediation plan.
- Security updates and vulnerabilities are identified and remediated according to policy.
- SSH, service accounts, file permissions, and logging follow the intended baseline.
- Unused services, packages, and accounts are removed.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/access-control-secrets.md`
- `docs/audits/network-exposure-firewall.md`
- `docs/audits/monitoring-alerting.md`
- `docs/audits/backup-integrity.md`
- `docs/RECOVERY.md`
- `docs/audits/incident-response-recovery.md`
