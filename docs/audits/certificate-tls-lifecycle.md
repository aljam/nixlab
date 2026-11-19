# Certificate and TLS lifecycle audit

Use this audit to periodically verify that TLS certificates are inventoried, renewed before expiry, deployed correctly, and protected from unauthorized access.

This audit must not expose private keys, certificate contents, tokens, passwords, or sensitive endpoint data. Record certificate names, issuers, expiry dates, renewal status, deployment targets, findings, and remediation actions only.

## Audit objective

For every TLS-enabled service and endpoint, verify that:

- Certificates are inventoried with an owner and renewal procedure.
- Certificates renew before expiry and deployment succeeds.
- Certificate expiry and renewal failures generate actionable alerts.
- TLS configuration uses supported protocols, ciphers, and certificate validation.
- Private keys are protected and not exposed in code, logs, or diagnostics.
- Compromised or revoked certificates are replaced promptly.
- TLS changes are reviewed, tested, and recorded.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Certificate inventory and expiry review | Monthly | Platform owner | Certificate names, issuers, expiry dates, and renewal status |
| Renewal and deployment review | Monthly | Platform owner | Renewal result, deployment result, and exceptions |
| TLS configuration review | Monthly | Platform owner | Protocol, cipher, and endpoint configuration findings |
| Private-key protection review | Monthly | Security owner | Key location, permissions, and exposure findings |
| Revocation and incident review | Quarterly | Security owner | Revocation status, incident links, and remediation status |
| Full audit review | Quarterly | Platform and security owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every TLS-enabled public and internal endpoint.
- [ ] Identify the certificate authority, issuance method, and renewal workflow.
- [ ] Identify the reverse-proxy, load-balancer, or service that terminates TLS.
- [ ] Identify the private-key storage location and access controls.
- [ ] Identify the certificate-expiry monitoring and alert-routing configuration.
- [ ] Confirm the audit environment cannot modify production certificates, keys, or TLS configuration.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm recent certificate renewals, deployments, incidents, and TLS changes are available for review.

## Certificate inventory

For every TLS certificate:

- [ ] Record the certificate name, hostname, issuer, and expiry date.
- [ ] Record the service or reverse proxy that uses the certificate.
- [ ] Record the certificate owner and renewal procedure.
- [ ] Confirm the certificate covers all intended hostnames.
- [ ] Confirm wildcard certificates are intentional and narrowly scoped.
- [ ] Confirm unused certificates are identified for revocation or removal.
- [ ] Confirm duplicate certificates do not create inconsistent renewal or deployment paths.
- [ ] Confirm certificate inventory is current and discoverable.

## Renewal and deployment

For every certificate:

- [ ] Confirm automatic renewal is configured where supported.
- [ ] Confirm renewal runs successfully or generates an actionable failure alert.
- [ ] Confirm renewal occurs before certificate expiry with sufficient lead time.
- [ ] Confirm renewed certificates are deployed to the intended TLS termination point.
- [ ] Confirm deployment completes without service interruption where possible.
- [ ] Confirm the deployed certificate matches the expected hostname and issuer.
- [ ] Confirm certificate reload or service restart succeeds where required.
- [ ] Confirm renewal or deployment failures generate an alert or incident record.
- [ ] Confirm renewal history and deployment outcomes are recorded.

## Expiry monitoring

For every TLS endpoint:

- [ ] Confirm certificate expiry is monitored.
- [ ] Confirm alerts fire before expiry with sufficient renewal lead time.
- [ ] Confirm alert severity matches the service impact of expiration.
- [ ] Confirm alerts route to an accountable owner or on-call rotation.
- [ ] Confirm alerts include the certificate name, hostname, and expiry date without exposing private keys.
- [ ] Confirm expired certificates are treated as service-impacting incidents.
- [ ] Confirm alert acknowledgements and remediation actions are recorded.
- [ ] Confirm monitoring remains active after certificate renewal or deployment.

## TLS configuration

For every TLS endpoint:

- [ ] Confirm the endpoint uses a supported TLS protocol version.
- [ ] Confirm deprecated or insecure protocol versions are disabled where supported.
- [ ] Confirm approved cipher suites and key-exchange groups are used.
- [ ] Confirm weak or legacy ciphers are disabled where supported.
- [ ] Confirm certificate hostname validation is enforced by clients where applicable.
- [ ] Confirm HTTP-to-HTTPS redirection is configured where applicable.
- [ ] Confirm HSTS is configured where appropriate.
- [ ] Confirm TLS configuration changes are reviewed and tested.
- [ ] Confirm TLS failures generate an alert where supported.

## Private-key protection

For every private key:

- [ ] Confirm the key is stored in the approved secret manager or protected key store.
- [ ] Confirm the key is not committed to the Git repository.
- [ ] Confirm the key is not present in Nix store paths, build outputs, logs, or diagnostics.
- [ ] Confirm key file ownership and permissions are restrictive.
- [ ] Confirm access is limited to approved services and operators.
- [ ] Confirm key access is logged or auditable where supported.
- [ ] Confirm keys are rotated or replaced according to policy.
- [ ] Confirm exposed or compromised keys are revoked and replaced promptly.
- [ ] Confirm incident records do not contain private-key material.

## Revocation and compromise

For every certificate:

- [ ] Confirm the revocation procedure is documented.
- [ ] Confirm the certificate authority or issuer supports revocation where applicable.
- [ ] Confirm compromised certificates are revoked promptly.
- [ ] Confirm replacement certificates are issued and deployed promptly.
- [ ] Confirm affected services and clients are identified.
- [ ] Confirm revocation and replacement outcomes are recorded.
- [ ] Confirm certificate-compromise incidents are linked to incident response and evidence preservation.
- [ ] Confirm root cause and recurrence prevention are documented.

## Findings and remediation

Classify each finding as:

- **Critical:** A certificate is expired, compromised, publicly exposed with its private key, or cannot be renewed or deployed.
- **High:** Renewal, monitoring, deployment, TLS configuration, or key-protection controls create a material service or security risk.
- **Medium:** A control is incomplete, undocumented, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected certificate, hostname, service, and control.
- [ ] Record the severity and potential impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as security or service incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Every TLS certificate is inventoried with an owner and renewal procedure.
- Certificates renew before expiry and deploy successfully.
- Certificate expiry and renewal failures generate actionable alerts.
- TLS configuration uses supported protocols and ciphers.
- Private keys remain protected and unexposed.
- Compromised certificates are revoked and replaced promptly.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/access-control-secrets.md`
- `docs/audits/network-exposure-firewall.md`
- `docs/audits/monitoring-alerting.md`
- `docs/audits/host-hardening-patching.md`
- `docs/RECOVERY.md`
- `docs/audits/incident-response-recovery.md`
