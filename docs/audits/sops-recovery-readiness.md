# SOPS recovery readiness

## Status

Implemented.

## Controls

- Every secret path must have exactly one explicit SOPS creation rule.
- Fleet-wide fallback rules are prohibited.
- Host authorization is validated against the declared creation rules.
- Secret recipients must be declared in `.sops.yaml`.
- Secret recipients must be authorized by the matching creation rule.

## Recovery drill

Run the SOPS recovery validation check:

```console
nix flake check --show-trace
nix build .#checks.x86_64-linux.sops-recovery
```

The check is non-decrypting: it validates creation-rule coverage and
recipient authorization without exposing secret contents in CI logs.

## Rebuilt or replaced host

Before deploying a rebuilt or replaced host:

1. Generate a new age recipient for the host.
2. Update `.sops.yaml` with the new recipient.
3. Remove the retired host recipient.
4. Re-encrypt every secret authorized for that host.
5. Run the SOPS recovery check.
6. Confirm the host can decrypt only its authorized secrets.
7. Deploy the host only after the check passes.
