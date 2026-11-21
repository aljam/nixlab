# Public-service recovery matrix

Use this matrix to decide what must be restored, verified, and rehearsed after an incident affecting a public-facing service.

A public-service recovery is not complete when the upstream service starts. It is complete when DNS resolves correctly, TLS is valid, the reverse proxy routes traffic to the intended upstream, the service passes health and functional checks, and monitoring remains healthy.

## Recovery scope

| Recovery area | Primary artifacts | Failure impact | Restore priority |
|---|---|---|---|
| DNS | DNS records, delegation, name servers | Clients cannot resolve or reach the intended service | P0 |
| TLS | Certificates, private keys, TLS configuration | Clients cannot establish trusted connections | P0 |
| Reverse proxy | Proxy configuration, routes, upstream definitions | Public traffic cannot reach the intended service | P0 |
| Public endpoint | Public hostname, firewall rules, endpoint configuration | The service is unreachable or exposed incorrectly | P0 |
| Upstream service | Service configuration, database, media, state | The service may be reachable but unusable | P0 |
| Authentication | Identity provider, SSO, OAuth, OIDC, credentials | Users cannot authenticate or authorize access | P1 |
| Monitoring | Health checks, alerts, dashboards, notification routing | Operators may not detect continued or recurring failure | P1 |
| Caches and queues | Cache state, message queues, job state | Service behavior, background jobs, or notifications may fail | P1 |
| Rate limiting and abuse controls | Rate-limit configuration, WAF rules, firewall rules | Public endpoints may be unavailable or abused | P2 |

## Before an incident

- [ ] Maintain an inventory of public hostnames, DNS records, TLS certificates, reverse-proxy routes, and upstream services.
- [ ] Maintain encrypted, off-site backups of reverse-proxy configuration, service configuration, databases, media, and required state.
- [ ] Maintain encrypted, off-site backups of TLS certificates and private keys where applicable.
- [ ] Document the intended public exposure for every service.
- [ ] Document the recovery sequence and dependencies for every public service.
- [ ] Document health checks, functional checks, and monitoring alerts for every public service.
- [ ] Confirm that recovery credentials use least privilege and are available through the approved secret manager.
- [ ] Confirm that the recovery environment cannot modify production DNS, TLS, firewall, or reverse-proxy configuration.
- [ ] Confirm that monitoring detects DNS, TLS, reverse-proxy, upstream-service, certificate, and capacity failures.

## DNS recovery

DNS must be restored and verified before public traffic can reliably reach the intended service.

- [ ] Identify the affected public hostname and DNS record.
- [ ] Confirm the DNS record is intentional and points to the intended public address or gateway.
- [ ] Confirm authoritative name servers are reachable and correctly delegated.
- [ ] Confirm the DNS record resolves from an external network where safe and authorized.
- [ ] Confirm wildcard records are intentional and narrowly scoped.
- [ ] Confirm Matrix delegation records, if applicable, point to the intended homeserver.
- [ ] Confirm stale, duplicate, or unintended records are removed.
- [ ] Confirm DNS changes are reviewed, tested, and recorded.
- [ ] Record the DNS record, intended target, resolution result, and recovery time.

## TLS recovery

TLS must be valid before clients can establish trusted connections.

- [ ] Identify the affected certificate, hostname, issuer, and expiry date.
- [ ] Confirm the certificate covers all intended hostnames.
- [ ] Confirm the certificate is valid and not expired.
- [ ] Confirm the private key is available through the approved secret manager or protected key store.
- [ ] Confirm the private key is not exposed in Git, logs, Nix store paths, or diagnostics.
- [ ] Restore or renew the certificate through the approved procedure.
- [ ] Deploy the certificate to the intended TLS termination point.
- [ ] Confirm TLS handshake succeeds from an external network where safe and authorized.
- [ ] Confirm HTTP-to-HTTPS redirection and HSTS are configured where applicable.
- [ ] Record the certificate, hostname, issuer, expiry date, and recovery result.

## Reverse-proxy recovery

The reverse proxy must route public traffic to the intended upstream service without exposing unintended services.

- [ ] Identify the affected public hostname, route, and upstream service.
- [ ] Confirm the reverse-proxy configuration is restored from the intended source.
- [ ] Confirm the route maps the public hostname to the intended upstream service.
- [ ] Confirm the route does not expose an unintended upstream service.
- [ ] Confirm the upstream address, port, and protocol are correct.
- [ ] Confirm required proxy headers and timeouts are configured.
- [ ] Confirm rate limiting and abuse controls are configured where applicable.
- [ ] Confirm proxy error pages do not expose internal addresses, stack traces, or sensitive configuration.
- [ ] Confirm reverse-proxy changes are reviewed, tested, and recorded.
- [ ] Record the route, upstream target, and verification result.

## Public-endpoint recovery

Public exposure must be intentional and minimized.

- [ ] Confirm the public endpoint is intentional and documented.
- [ ] Confirm the public hostname resolves to the intended gateway or service.
- [ ] Confirm required firewall rules permit only required traffic.
- [ ] Confirm administrative interfaces, databases, caches, message queues, and internal services are not publicly reachable.
- [ ] Confirm debug endpoints, metrics, source maps, and sensitive diagnostics are not publicly exposed unless explicitly approved.
- [ ] Confirm the endpoint responds with the expected status and content.
- [ ] Confirm public-endpoint changes are reviewed, tested, and recorded.
- [ ] Record the endpoint, firewall policy, and external verification result.

## Upstream-service recovery

The upstream service must be restored and validated before public traffic is promoted.

- [ ] Identify the affected service, its configuration, database, media, and required state.
- [ ] Restore the service configuration from the intended source.
- [ ] Restore the database, media, or state using the applicable recovery procedure.
- [ ] Start the service in an isolated recovery environment first where feasible.
- [ ] Confirm required database migrations or background jobs complete successfully.
- [ ] Confirm the service passes health checks.
- [ ] Confirm a representative functional check succeeds.
- [ ] Confirm required dependencies, such as databases, caches, queues, and storage, are available.
- [ ] Confirm no production data was overwritten or exposed.
- [ ] Record the service, recovery point, validation result, and recovery time.

## Authentication recovery

Users must be able to authenticate and authorize access after recovery.

- [ ] Identify the authentication method and identity provider.
- [ ] Confirm the identity provider is reachable and healthy.
- [ ] Confirm SSO, OAuth, OIDC, LDAP, or local authentication is configured correctly.
- [ ] Confirm required client IDs, secrets, redirect URIs, and certificates are available.
- [ ] Confirm at least one authorized user can authenticate.
- [ ] Confirm authorization and role-based access behave as expected.
- [ ] Confirm recovery access does not rely solely on an external identity provider.
- [ ] Confirm authentication credentials are stored in the approved secret manager.
- [ ] Record the authentication method, test user, and verification result.

## Monitoring recovery

Monitoring must detect both immediate and recurring failures after recovery.

- [ ] Confirm service health checks are active.
- [ ] Confirm DNS, TLS, reverse-proxy, upstream-service, and capacity alerts are active.
- [ ] Confirm certificate-expiry monitoring is active.
- [ ] Confirm backup and recovery alerts are active where applicable.
- [ ] Confirm alerts route to an accountable owner or on-call rotation.
- [ ] Confirm alert severity matches the service impact.
- [ ] Confirm a representative alert-routing path is tested where feasible.
- [ ] Confirm monitoring dashboards reflect the recovered service state.
- [ ] Record the alert coverage and routing verification result.

## Recovery sequence

Use this order for a public-service recovery:

1. Preserve evidence and establish an isolated recovery environment.
2. Restore and verify DNS.
3. Restore and verify TLS certificates and private keys.
4. Restore and verify reverse-proxy configuration.
5. Restore and verify firewall and public-endpoint exposure.
6. Restore the upstream service, database, media, and required state.
7. Restore and verify authentication.
8. Restore and verify monitoring and alert routing.
9. Restore caches, queues, and background-job state where applicable.
10. Verify public access, health, functionality, and security boundaries.
11. Promote the recovered environment to production only after all P0 checks pass.
12. Record outcomes, gaps, and follow-up actions.

## Pass criteria

The public-service recovery is successful when:

- DNS resolves to the intended public endpoint.
- TLS is valid and trusted.
- The reverse proxy routes traffic to the intended upstream service.
- The upstream service passes health and functional checks.
- Authentication works for an authorized user.
- Public exposure remains intentional and minimized.
- Monitoring and alert routing remain healthy.
- The recovery point meets the accepted freshness objective.
- Results, gaps, and follow-up actions are recorded.

## If recovery fails

- Preserve DNS records, TLS certificates, reverse-proxy configuration, service logs, monitoring data, and recovery-point references.
- Do not delete backups, certificates, or repository snapshots until the cause is understood.
- Determine whether the failure is in DNS, TLS, reverse proxy, firewall, upstream service, authentication, monitoring, or recovery data.
- Treat inability to restore a usable public service as a recoverability incident.
- Follow `docs/runbooks/incident-severity.md` to assign severity and preserve evidence.
- Follow `docs/runbooks/incident-evidence.md` for evidence handling.

## Related documentation

- `docs/PUBLIC_SERVICES.md`
- `docs/public-endpoints.json`
- `docs/NETWORKING.md`
- `docs/runbooks/service-recovery-matrix.md`
- `docs/runbooks/restic-restore-drill.md`
- `docs/runbooks/postgresql-restore-drill.md`
- `docs/runbooks/matrix-recovery-matrix.md`
- `docs/runbooks/incident-severity.md`
- `docs/runbooks/incident-evidence.md`
- `docs/audits/certificate-tls-lifecycle.md`
- `docs/audits/dns-domain-management.md`
- `docs/audits/network-exposure-firewall.md`
- `docs/audits/monitoring-alerting.md`
- `docs/RECOVERY.md`
- `docs/audits/incident-response-recovery.md`
