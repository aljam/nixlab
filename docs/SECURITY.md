# Security

## SOPS

SOPS secrets use per-host age recipients. Each secret file has exactly one
explicit creation rule, and fleet-wide fallback rules are prohibited.

The SOPS recovery drill validates that a representative host can decrypt only
its assigned secret and cannot decrypt an unrelated secret. See
[`docs/audits/sops-recovery-readiness.md`](audits/sops-recovery-readiness.md).

## Alertmanager

Alertmanager and its Ntfy relay run only on the Prometheus host (r730xd).
Alertmanager listens only on loopback and is intentionally excluded from
`networking.proxyBackendPorts`. Prometheus reaches it locally at
`127.0.0.1:9093`. Clustering is disabled, so the gossip port (`9094`) is not
used.
