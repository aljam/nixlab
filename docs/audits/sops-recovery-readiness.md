# SOPS recovery readiness

## Status

Implemented.

## Controls

- Every secret path must have exactly one explicit SOPS creation rule.
- Fleet-wide fallback rules are prohibited.
- Host authorization is validated against the declared host-to-secret matrix.
- A representative host must decrypt only its assigned secret.
- A host must not decrypt an unrelated secret.
- Retired hosts and revoked recipients must not remain authorized.

## Recovery drill

Run:

```console
nix flake check --show-trace
nix run .#vm -- --run sops-recovery
```

The drill is non-decrypting from the operator's perspective: it validates
authorization and isolation without exposing secret contents in CI logs.

## Rebuilt or replaced host

Before deploying a rebuilt or replaced host:

1. Generate a new age recipient for the host.
2. Update `.sops.yaml` with the new recipient.
3. Remove the retired host recipient.
4. Re-encrypt every secret authorized for that host.
5. Run the SOPS recovery drill.
6. Confirm the host can decrypt only its authorized secrets.
7. Deploy the host only after the drill passes.
