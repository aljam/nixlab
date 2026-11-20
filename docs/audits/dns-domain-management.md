# DNS and domain-management audit

Use this audit to periodically verify that domains, DNS records, delegation, and registrar access are intentional, current, protected, and recoverable.

This audit must not expose registrar credentials, API tokens, private keys, or sensitive internal network details. Record domain names, record types, delegation targets, expiration dates, findings, and remediation actions only.

## Audit objective

For every production domain and DNS zone, verify that:

- Domain registration and DNS hosting are current and recoverable.
- DNS records are intentional, documented, and owned.
- Delegation and mail records point to the intended services.
- DNSSEC is configured where supported.
- Registrar and DNS-provider access use least privilege and MFA.
- Domain and DNS-record expiration are monitored.
- Unused or unintended records are removed.
- DNS changes are reviewed, tested, and recorded.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Domain registration and expiration review | Monthly | Platform owner | Domain names, registrars, expiration dates, and renewal status |
| DNS record inventory review | Monthly | Platform owner | Record inventory, owners, and exceptions |
| Delegation and mail-record review | Monthly | Platform owner | Delegation targets, mail records, and exceptions |
| DNSSEC review | Monthly | Platform owner | DNSSEC status, DS records, and exceptions |
| Registrar and DNS-provider access review | Quarterly | Security owner | Access list, MFA status, and exceptions |
| DNS change review | Monthly | Platform owner | Change records, test results, and exceptions |
| Full audit review | Quarterly | Platform and security owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every production domain and subdomain.
- [ ] Identify the registrar, DNS provider, and authoritative name servers for each domain.
- [ ] Identify the intended DNS records and delegation targets.
- [ ] Identify mail, SPF, DKIM, DMARC, and MX requirements where applicable.
- [ ] Identify the registrar and DNS-provider access controls.
- [ ] Confirm the audit environment cannot modify production DNS records or registrar settings.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm recent DNS changes, domain renewals, and incidents are available for review.

## Domain registration

For every production domain:

- [ ] Confirm the domain is registered to the intended organization or owner.
- [ ] Confirm the registrar account is documented and owned.
- [ ] Confirm the domain expiration date is monitored.
- [ ] Confirm automatic renewal is enabled where supported.
- [ ] Confirm renewal payment or billing status is current.
- [ ] Confirm domain-lock or transfer-lock protection is enabled where supported.
- [ ] Confirm recovery contacts and registrant details are current.
- [ ] Confirm domain-transfer procedures require appropriate approval.
- [ ] Confirm expired or unused domains are identified for renewal, release, or documented retention.

## DNS record inventory

For every DNS zone:

- [ ] Identify every DNS record and its type, name, target, and TTL.
- [ ] Confirm each record has a documented owner and purpose.
- [ ] Confirm records resolve to the intended public service or endpoint.
- [ ] Confirm internal-only services are not exposed through public DNS.
- [ ] Confirm wildcard records are intentional and narrowly scoped.
- [ ] Confirm stale, duplicate, or unused records are removed.
- [ ] Confirm record changes are reviewed and tested.
- [ ] Confirm DNS record inventory is current and discoverable.

## Delegation and routing

For every delegation or routing record:

- [ ] Confirm the authoritative name servers are intentional and reachable.
- [ ] Confirm `A`, `AAAA`, and `CNAME` records point to the intended service.
- [ ] Confirm reverse-proxy or gateway records route traffic to the intended upstream service.
- [ ] Confirm Matrix delegation records, if used, point to the intended homeserver.
- [ ] Confirm service-specific delegation records are intentional and documented.
- [ ] Confirm delegation changes are reviewed and tested.
- [ ] Confirm delegation does not expose unintended internal services.
- [ ] Confirm stale delegation records are removed.

## Mail records

For every domain that sends or receives mail:

- [ ] Confirm MX records point to the intended mail service.
- [ ] Confirm SPF records authorize only intended sending sources.
- [ ] Confirm DKIM selectors and keys are current and documented.
- [ ] Confirm DMARC policy is configured and monitored.
- [ ] Confirm mail-related records do not authorize unintended senders.
- [ ] Confirm mail-record changes are reviewed and tested.
- [ ] Confirm mail-delivery failures generate an alert where supported.
- [ ] Confirm unused mail records are removed.

## DNSSEC

For every DNS zone where DNSSEC is supported:

- [ ] Confirm DNSSEC is enabled where intended.
- [ ] Confirm the DNSSEC signing key is protected and access-controlled.
- [ ] Confirm the DS record at the parent zone matches the current DNSSEC key.
- [ ] Confirm DNSSEC key rotation is documented and tested where supported.
- [ ] Confirm DNSSEC validation failures generate an alert where supported.
- [ ] Confirm DNSSEC changes are reviewed and tested.
- [ ] Confirm DNSSEC exceptions have an owner, justification, and review date.

## Registrar and DNS-provider access

For every registrar and DNS provider:

- [ ] Confirm access is limited to approved identities.
- [ ] Confirm MFA is enabled for registrar and DNS-provider accounts.
- [ ] Confirm API tokens use least privilege.
- [ ] Confirm API tokens are stored in the approved secret manager.
- [ ] Confirm tokens are not embedded in code, configuration, logs, or documentation.
- [ ] Confirm unused tokens and accounts are revoked.
- [ ] Confirm access changes are reviewed and approved.
- [ ] Confirm credential rotation or replacement plans exist.
- [ ] Confirm privileged DNS or registrar actions are logged or auditable where supported.

## Change management

For every DNS or domain change:

- [ ] Confirm the change has a documented purpose and scope.
- [ ] Confirm the change identifies affected domains, records, and services.
- [ ] Confirm the change is reviewed and approved.
- [ ] Confirm the change is tested in a safe environment where feasible.
- [ ] Confirm DNS propagation and resolution are verified after deployment.
- [ ] Confirm rollback steps are documented.
- [ ] Confirm failed changes have an owner and remediation plan.
- [ ] Confirm change records do not contain registrar credentials or API tokens.

## Findings and remediation

Classify each finding as:

- **Critical:** A domain is expired, transferable without control, DNSSEC is broken, or DNS delegation exposes an unintended service.
- **High:** Registrar access, DNS records, mail authentication, or change controls create a material availability or security risk.
- **Medium:** A control is incomplete, undocumented, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected domain, record, registrar, provider, or control.
- [ ] Record the severity and potential impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as security or availability incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Every production domain is registered, owned, and renewed before expiry.
- DNS records are intentional, documented, and owned.
- Delegation and mail records point to the intended services.
- DNSSEC is configured where supported.
- Registrar and DNS-provider access use least privilege and MFA.
- DNS changes are reviewed, tested, and recorded.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/access-control-secrets.md`
- `docs/audits/certificate-tls-lifecycle.md`
- `docs/audits/network-exposure-firewall.md`
- `docs/audits/monitoring-alerting.md`
- `docs/RECOVERY.md`
- `docs/audits/incident-response-recovery.md`
