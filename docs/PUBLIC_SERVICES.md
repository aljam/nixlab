# Public service security review

This document defines the security baseline for services exposed through the
pfSense HAProxy gateway. It complements `docs/SECURITY.md` and the centralized
backend firewall rules in `modules/features/reverse-proxy-backends.nix`.

## Exposure model

- Public clients reach services only through HAProxy on pfSense.
- HAProxy is the only permitted source for connections to service backend
  ports declared in `networking.proxyBackendPorts`.
- Backend services must not be directly reachable from the LAN or internet.
- Every public hostname must have an identified owner, intended audience, and
  authentication mechanism.

## TLS requirements

HAProxy must enforce the following for every public frontend:

- HTTPS-only access, with an automatic redirect from HTTP to HTTPS.
- A valid certificate for every served hostname.
- Automated certificate renewal and expiration monitoring.
- TLS 1.2 or newer; TLS 1.0 and 1.1 must be disabled.
- A modern, maintained cipher suite; avoid export, anonymous, and deprecated
  cipher suites.
- HTTP/2 only where the backend and HAProxy configuration support it safely.

## Required response headers

Apply these headers at HAProxy unless a specific application has a documented
exception:

- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-Frame-Options: DENY`, or an application-specific CSP `frame-ancestors`
  directive where embedding is required.
- A restrictive `Content-Security-Policy` where the application supports it.

Do not add headers that conflict with an application’s required embedding,
API, or media-streaming behavior without documenting the exception.

## Authentication review

For each public service, record and verify:

- The authentication method: local accounts, OIDC/SSO, API token, or another
  reviewed mechanism.
- Whether administrative interfaces are publicly reachable.
- Whether self-registration is disabled.
- Whether multi-factor authentication is available and enabled for
  administrators.
- Session lifetime, cookie security flags, and logout behavior.
- Whether rate limiting or brute-force protection is configured.
- Whether service-to-service credentials are stored in SOPS and scoped to the
  minimum required permissions.

## Internal-only services

The following services must not appear in `networking.proxyBackendPorts` or be
advertised on the public Homepage dashboard:

- pgAdmin
- PostgreSQL
- Prometheus
- Prometheus Blackbox exporter
- Alertmanager

These restrictions are enforced by assertions in
`modules/features/security-policy.nix` and related service modules.

## Verification

Before merging an exposure change:

1. Run `nix flake check --show-trace`.
2. Build every affected host.
3. Confirm the new backend port is intentionally required.
4. Confirm HAProxy routes only the intended hostname to the intended backend.
5. Confirm the service requires authentication appropriate to its sensitivity.
6. Confirm TLS, redirects, certificate renewal, and required headers work.
7. Confirm the service is absent from public dashboards if it is internal-only.
