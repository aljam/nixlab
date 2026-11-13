# Host baseline audit

## Status

Implemented.

## Controls

- Detect failed system and user systemd units.
- Measure persistent journal disk usage.
- Verify that audit records are recent and available.
- Verify SSH password authentication, interactive authentication, and direct root login remain disabled.
- Count recent privileged and identity-change audit events.
- Export baseline findings through node_exporter.
- Alert on failed units, excessive journal usage, stale audit records, and SSH hardening regressions.

## Validation

Build and run the NixOS VM test:

```console
nix flake check --show-trace
nix build .#checks.x86_64-linux.host-baseline
./result/bin/nixos-test-driver
```

The audit is read-only and does not expose secret values or decrypted SOPS
contents.
