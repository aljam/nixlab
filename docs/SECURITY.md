# Security

## SOPS

SOPS secrets use per-host age recipients. Each secret file has exactly one
explicit creation rule, and fleet-wide fallback rules are prohibited.

The SOPS recovery drill validates that a representative host can decrypt only
its assigned secret and cannot decrypt an unrelated secret. See
[`docs/audits/sops-recovery-readiness.md`](audits/sops-recovery-readiness.md).

## SSH access

SSH access is key-only and group-based.

- Password authentication is disabled.
- Empty passwords are disabled.
- Direct root login is disabled.
- Interactive keyboard authentication is disabled.
- X11, TCP, and SSH-agent forwarding are disabled.
- Members of `wheel` may log in with public keys.
- When the deploy user feature is enabled, members of `deploy` may also log in.

Adding a user to `wheel` intentionally grants both SSH access and
administrative privileges. Do not add users or groups to SSH access without
updating the underlying role or deployment policy.

Fail2ban constrains repeated key probing, connection abuse, and noisy
authentication attempts. It is not a password-brute-force control because
password authentication is disabled.

## Alertmanager

Alertmanager and its Ntfy relay run only on the Prometheus host (r730xd).
Alertmanager listens only on loopback and is intentionally excluded from
`networking.proxyBackendPorts`. Prometheus reaches it locally at
`127.0.0.1:9093`. Clustering is disabled, so the gossip port (`9094`) is not
used.
