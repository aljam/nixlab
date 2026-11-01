# Security posture

## Container images

OCI container images intentionally use floating version tags such as
`:latest` so security hotfixes can be adopted quickly on the next host
rebuild.

This favors timely patching over bit-for-bit reproducibility. Before a major
container upgrade, inspect upstream release notes and verify service health
after deployment.

## Alertmanager

Alertmanager listens only on loopback and is intentionally excluded from
`networking.proxyBackendPorts`. Prometheus reaches it locally at
`127.0.0.1:9093`.

Alerts are currently visible only in the Prometheus and Alertmanager UIs; no
external notification receiver is configured.

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
