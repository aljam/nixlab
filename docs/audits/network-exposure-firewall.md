# Network exposure and firewall audit

Use this audit to periodically verify that network services are exposed only where required, firewall rules match the intended architecture, and administrative interfaces are not reachable from untrusted networks.

This audit must not expose private addresses, credentials, tokens, internal topology details, or sensitive service data in public records. Record service names, intended exposure, firewall policy references, findings, and remediation actions only.

## Audit objective

For every production host, container, and network service, verify that:

- Listening services are identified and owned.
- Public exposure is intentional, documented, and minimized.
- Firewall rules permit only required traffic.
- Administrative interfaces are protected from untrusted networks.
- Reverse-proxy routing and TLS configuration match the intended service exposure.
- DNS records do not expose unintended services.
- Firewall, proxy, and DNS changes are reviewed, tested, and recorded.
- Exposure findings have an owner and remediation plan.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Listening-service inventory | Monthly | Platform owner | Service inventory, listening state, and ownership |
| Firewall-rule review | Monthly | Platform owner | Rule references, intended policy, and exceptions |
| Public-exposure review | Monthly | Platform owner | Public endpoints, DNS records, and exposure decisions |
| Administrative-interface review | Monthly | Security owner | Interface inventory, access controls, and exceptions |
| Reverse-proxy and TLS review | Monthly | Platform owner | Routing configuration, certificate status, and exceptions |
| External exposure test | Quarterly | Security owner | Test scope, results, and remediation status |
| Full audit review | Quarterly | Platform and security owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every production host, container, and network service.
- [ ] Identify the intended public, LAN, and loopback exposure for each service.
- [ ] Identify the firewall system and rule sources.
- [ ] Identify reverse-proxy, DNS, and TLS configuration.
- [ ] Identify administrative interfaces and management ports.
- [ ] Confirm the audit environment cannot modify production firewall rules or expose new services.
- [ ] Confirm audit credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm recent network, firewall, proxy, and DNS changes are available for review.

## Listening services

For each production host and container:

- [ ] Identify every listening TCP and UDP socket.
- [ ] Confirm each listening service has a documented owner and purpose.
- [ ] Confirm the service binds only to the intended interface or address.
- [ ] Confirm services intended for local use bind to loopback where possible.
- [ ] Confirm services intended for LAN use bind only to the intended LAN interface.
- [ ] Confirm services intended for public use are exposed through the intended reverse proxy or firewall policy.
- [ ] Confirm unexpected listeners are investigated and remediated.
- [ ] Confirm deprecated or unused services are disabled or removed.
- [ ] Confirm service exposure changes are reviewed and recorded.

## Firewall policy

For each firewall zone and host:

- [ ] Confirm the default policy denies unsolicited inbound traffic.
- [ ] Confirm inbound rules permit only required protocols, ports, and sources.
- [ ] Confirm outbound rules permit only required destinations where outbound filtering is used.
- [ ] Confirm administrative interfaces are restricted to approved management networks or identities.
- [ ] Confirm database, cache, message-queue, and internal-service ports are not exposed publicly.
- [ ] Confirm firewall rules do not contain overly broad source ranges without justification.
- [ ] Confirm temporary rules have an owner, justification, and expiration date.
- [ ] Confirm firewall-rule changes are reviewed, tested, and recorded.
- [ ] Confirm firewall failures or misconfigurations generate an alert where supported.

## Public exposure

For each public endpoint:

- [ ] Confirm the endpoint is intentional and documented.
- [ ] Confirm the public hostname resolves to the intended service.
- [ ] Confirm the endpoint is served through the intended reverse proxy or gateway.
- [ ] Confirm the endpoint uses TLS where applicable.
- [ ] Confirm the endpoint does not expose an administrative interface, database, cache, message queue, or internal service.
- [ ] Confirm public endpoints do not expose source maps, debug endpoints, metrics, or sensitive diagnostics unless explicitly approved.
- [ ] Confirm public endpoints have rate limiting or abuse controls where applicable.
- [ ] Confirm public exposure changes are reviewed and approved.
- [ ] Confirm unused public DNS records and endpoints are removed.

## Administrative interfaces

For each administrative interface:

- [ ] Identify the interface, port, service, and owner.
- [ ] Confirm the interface is not reachable from the public internet unless explicitly required and protected.
- [ ] Confirm administrative interfaces are restricted to approved management networks, VPNs, or identities.
- [ ] Confirm administrative interfaces require authentication and MFA where supported.
- [ ] Confirm default credentials are removed or replaced.
- [ ] Confirm administrative sessions are logged or auditable where supported.
- [ ] Confirm administrative access follows the break-glass and access-control procedures.
- [ ] Confirm administrative interfaces do not expose secrets, tokens, private keys, or sensitive data.
- [ ] Confirm administrative-interface exposure changes are reviewed and approved.

## Reverse proxy and TLS

For each reverse-proxy route:

- [ ] Confirm the route maps the intended public hostname to the intended upstream service.
- [ ] Confirm the route does not expose an unintended upstream service.
- [ ] Confirm the route applies TLS where applicable.
- [ ] Confirm the TLS certificate matches the expected hostname.
- [ ] Confirm the certificate is valid and not expired.
- [ ] Confirm HTTP-to-HTTPS redirection is configured where applicable.
- [ ] Confirm security headers are configured where applicable.
- [ ] Confirm proxy error pages do not expose internal addresses, stack traces, or sensitive configuration.
- [ ] Confirm reverse-proxy changes are reviewed, tested, and recorded.

## DNS and delegation

For each DNS record:

- [ ] Confirm the record is intentional and documented.
- [ ] Confirm the record resolves to the intended public address or service.
- [ ] Confirm the record does not expose an internal-only service.
- [ ] Confirm wildcard records are intentional and narrowly scoped.
- [ ] Confirm Matrix delegation records, if used, point to the intended homeserver.
- [ ] Confirm DNS changes are reviewed and tested.
- [ ] Confirm unused DNS records are removed.
- [ ] Confirm DNS changes do not create unintended public exposure.

## External exposure testing

- [ ] Test public endpoints from an external network where safe and authorized.
- [ ] Confirm only intended public services respond.
- [ ] Confirm administrative interfaces are not reachable from the public internet.
- [ ] Confirm internal databases, caches, message queues, and management ports are not reachable from the public internet.
- [ ] Confirm unexpected open ports or services are investigated.
- [ ] Confirm TLS endpoints present valid certificates.
- [ ] Confirm results do not expose internal addresses, credentials, or sensitive service data.
- [ ] Record the test scope, results, and remediation actions.

## Findings and remediation

Classify each finding as:

- **Critical:** An administrative interface, database, cache, message queue, or sensitive service is reachable from an untrusted network.
- **High:** Firewall, proxy, DNS, or TLS configuration creates a material exposure or service-availability risk.
- **Medium:** A control is incomplete, undocumented, overly broad, or inconsistently applied.
- **Low:** Documentation, hygiene, or reporting improvement is needed.

For every finding:

- [ ] Record the affected host, service, port, firewall rule, DNS record, or proxy route.
- [ ] Record the severity and potential impact.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm critical findings are treated as security incidents.
- [ ] Confirm remediation is verified before the finding is closed.

## Pass criteria

The audit passes only when:

- Every listening service is identified and owned.
- Public exposure is intentional, documented, and minimized.
- Firewall rules permit only required traffic.
- Administrative interfaces are protected from untrusted networks.
- Reverse-proxy routing and TLS configuration match the intended exposure.
- DNS records do not expose unintended services.
- External exposure testing validates the intended boundary.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/access-control-secrets.md`
- `docs/audits/monitoring-alerting.md`
- `docs/audits/backup-integrity.md`
- `docs/RECOVERY.md`
- `docs/audits/incident-response-recovery.md`
