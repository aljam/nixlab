# VM tests

NixOS VM tests are exposed as flake checks. Build a test, then run its
generated driver:

```console
nix build .#checks.x86_64-linux.<test-name>
./result/bin/nixos-test-driver
```

For example:

```console
nix build .#checks.x86_64-linux.alert-delivery
./result/bin/nixos-test-driver
```

The repository does not provide a generic `.#vm` application.

| Test | Type | Purpose |
|---|---|---|
| `firewall-isolation` | VM | Verifies that only HAProxy can reach an allowed backend port. |
| `admin-isolation` | VM | Verifies administrative-service isolation. |
| `monitoring-health` | VM | Verifies Prometheus startup, rules, exporters, and monitoring isolation. |
| `postgresql-auth` | VM | Verifies PostgreSQL TCP authentication. |
| `alert-delivery` | VM | Verifies Alertmanager-to-Ntfy delivery and recovery notifications. |
| `drift-detection` | VM | Verifies configuration and service drift detection. |
| `sops-recovery` | VM | Verifies SOPS recovery authorization and isolation. |
| `host-baseline` | VM | Verifies host baseline metrics and SSH hardening. |

Run one check:

```console
nix build .#checks.x86_64-linux.<test-name>
```

Run all evaluation checks:

```console
nix flake check --show-trace
```
