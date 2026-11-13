# Tests

This directory contains NixOS VM tests and repository policy checks.

## VM tests

VM tests are too slow to run in the normal `nix flake check` workflow. Build
and run them individually:

```console
nix build .#checks.x86_64-linux.<test-name>
./result/bin/nixos-test-driver
```

For example:

```console
nix build .#checks.x86_64-linux.alert-delivery
./result/bin/nixos-test-driver
```

| Test | Type | Purpose |
|---|---|---|
| `alert-delivery` | VM | Verifies Alertmanager-to-Ntfy delivery and recovery notifications. |
| `drift-detection` | VM | Verifies configuration and service drift detection. |
| `host-baseline` | VM | Verifies host baseline metrics and SSH hardening. |
| `sops-recovery` | Policy check | Validates SOPS creation-rule coverage and recipient authorization. |

## Policy checks

Policy checks run during `nix flake check`:

```console
nix flake check --show-trace
```
