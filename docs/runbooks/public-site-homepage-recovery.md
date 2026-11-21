# Public-site and Homepage recovery

This runbook defines the recovery and verification steps for the public static site and Homepage on `r730xd`. It covers content or configuration recovery, reverse-proxy exposure, public-endpoint validation, and monitoring checks.

Use this runbook after a host rebuild, configuration loss, reverse-proxy change, certificate renewal, or extended service outage. Do not restore content or configuration directly over live production state without first preserving the current state and confirming that the target is an isolated recovery environment.

## Scope

This runbook covers:

- The public static site.
- Homepage.
- The reverse-proxy routes that expose them.
- Public-endpoint health and monitoring.

It does not replace the generic [public-service recovery matrix](public-service-recovery-matrix.md), [Restic restore drill](restic-restore-drill.md), or host-compromise recovery procedure. Use those procedures first when DNS, TLS, the reverse proxy, or the underlying host requires recovery.

## Recovery dependencies

| Component | Persistent state | Depends on | Recovery role |
|---|---|---|---|
| Static site | Site content or generated output | Host storage, reverse proxy, DNS, TLS | Restore content before endpoint validation |
| Homepage | Configuration and link definitions | Reverse proxy, upstream service availability | Restore configuration before endpoint validation |
| Reverse proxy | Route and upstream configuration | DNS, TLS, firewall policy | Must route only intended services |
| Monitoring | Health checks and alert routing | Prometheus, Alertmanager, notification relay | Must detect recovery failure |

## Recovery order

Perform the steps in this order. Do not proceed to the next phase until the checks for the current phase pass.

1. **Preserve evidence and establish an isolated recovery target.**
2. **Recover the static site.**
3. **Recover Homepage.**
4. **Verify reverse-proxy exposure.**
5. **Verify public endpoints.**
6. **Verify monitoring and record the outcome.**

## Static-site recovery

Determine whether the static-site content is fully declarative, generated from a source repository, or persisted outside the Nix store before restoring it.

Verify:

- The intended site source or content recovery point is identified.
- The recovered content matches the expected source revision or backup.
- The site files are deployed to the expected service path.
- The static-site service is active.
- The site responds with the expected HTTP status and content.
- No stale, unintended, or sensitive content is exposed.

If the site is fully declarative, redeploying the authorized NixOS revision should restore it. If content is persisted, restore it from an approved recovery point and validate the recovered content before promoting it.

## Homepage recovery

Determine whether Homepage configuration is declarative, persisted, or a combination of both before restoring it.

Verify:

- The intended Homepage configuration source or recovery point is identified.
- The recovered configuration matches the expected source revision or backup.
- Homepage service state, if persistent, is restored to the correct ownership and permissions.
- The Homepage service is active.
- The web UI responds on its configured port.
- Configured links resolve to the intended services.
- No unintended service links, administrative endpoints, or internal addresses are exposed.

If Homepage configuration is declarative, redeploying the authorized NixOS revision should restore it. If configuration or state is persisted, restore it from an approved recovery point and validate it before promoting it.

## Reverse-proxy recovery

The reverse proxy must expose only the intended public services and route traffic to the correct upstreams.

Verify:

- The static-site and Homepage routes are present in the reverse-proxy configuration.
- Each route maps to the intended upstream service and port.
- No unintended internal service is exposed through the public reverse proxy.
- Required proxy headers, timeouts, and access controls are configured.
- DNS resolves the public hostname to the intended gateway or service.
- TLS is valid and trusted for every intended public hostname.
- HTTP-to-HTTPS redirection and HSTS are configured where applicable.

Do not promote a recovered endpoint until its public exposure has been reviewed. A reachable service with an unintended route is a security incident, not a successful recovery.

## Public-endpoint validation

Validate both services from an external network where safe and authorized.

Verify:

- The static-site public endpoint returns the expected status and content.
- The Homepage public endpoint returns the expected status and content.
- TLS handshakes succeed for both endpoints.
- The reverse proxy routes requests to the intended upstream services.
- Error pages do not expose internal addresses, stack traces, or sensitive configuration.
- No administrative interface, database, cache, metrics endpoint, or internal service is publicly reachable.

## Monitoring recovery

Verify that monitoring detects both immediate and recurring failures.

Verify:

- Static-site and Homepage health checks are active.
- Public-endpoint, DNS, TLS, reverse-proxy, and upstream-service alerts are active.
- Certificate-expiry monitoring is active where applicable.
- Alerts route to the intended notification path.
- A representative alert-routing path is tested where feasible.
- Monitoring dashboards reflect the recovered service state.

## Completion criteria

The public site and Homepage are not recovered until all of the following are true:

- The static site serves the expected content from the intended source or recovery point.
- Homepage serves the expected configuration and its links resolve to the intended services.
- The reverse proxy exposes only the intended public routes.
- DNS and TLS are valid for both public endpoints.
- Public endpoints return the expected status and content.
- Monitoring is healthy and no unexpected public-service alerts remain active.
- The recovery actions, failed checks, and final validation results are recorded in the incident record.

## Related documentation

- [Public-service recovery matrix](public-service-recovery-matrix.md)
- [Restic restore drill](restic-restore-drill.md)
- [Service recovery and verification inventory](service-recovery-matrix.md)
- [Host compromise recovery](host-compromise-recovery.md)
- [Incident evidence preservation](incident-evidence.md)
- [Incident severity](incident-severity.md)
