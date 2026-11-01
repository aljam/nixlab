# Security posture

## Container images

OCI container images intentionally use floating version tags such as
`:latest` so security hotfixes can be adopted quickly on the next host
rebuild.

This favors timely patching over bit-for-bit reproducibility. Before a major
container upgrade, inspect upstream release notes and verify service health
after deployment.

## SOPS secrets

Secrets are service-scoped to reduce blast radius. NAS credentials are
available only to `aljam`, `navi`, and `oryx`; servers do not receive NAS
credentials.

Every secret file must have an explicit SOPS creation rule. There is no
fleet-wide fallback rule.

## Alertmanager

Alertmanager listens only on loopback and is intentionally excluded from
`networking.proxyBackendPorts`. Prometheus reaches it locally at
`127.0.0.1:9093`.

Alerts are currently visible only in the Prometheus and Alertmanager UIs; no
external notification receiver is configured.

## CI

CI workflows use least-privilege GitHub token permissions. Cachix uploads are
restricted to `main` pushes and manual workflow dispatches; pull requests
validate builds without performing cache uploads.

## Enforced policies

The repository enforces these invariants at evaluation time:

- Every SOPS secret declares an explicit `sopsFile`.
- PostgreSQL does not use broad `host all all` authentication rules.
- pgAdmin and PostgreSQL are not exposed through the HAProxy backend
  allowlist.
- Alertmanager is not exposed through the HAProxy backend allowlist.
- Services using `servicesBindAddress` do not bind to every interface.
- HAProxy backend ports are unique.
- Autobrr does not bind to `0.0.0.0`.
- Recyclarr requires the Servarr stack.
- Server hosts do not enable Steam or GameScope.
- SSH password authentication, interactive authentication, and direct root
  login remain disabled.
