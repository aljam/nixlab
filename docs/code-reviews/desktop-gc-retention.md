# Code review: desktop Nix GC retention

## Goal

Give desktop hosts a longer Nix rollback window while preserving the existing controlled GC behavior and server retention policy.

## Current state

- The controlled GC module retains the current generation and a configurable minimum number of generations.
- It removes only unprotected generations older than the configured age.
- The current common policy is 4 generations and 14 days.
- Desktop hosts are more likely to need rollback after desktop, driver, kernel, or user-environment changes.

## Intended change

1. Retain the server policy unchanged: 4 generations and 14 days.
2. Apply a desktop policy to `navi` and `oryx`: 8 generations and 30 days.
3. Keep the current-generation protection and the minimum-generation guarantee unchanged.
4. Keep the weekly GC schedule unchanged.
5. Export the effective retention policy and last GC result through the existing node-exporter textfile metrics.
6. Extend the existing `nix-gc-policy` and `nix-gc-observability` tests to cover both host classes.

## Security review

- No new network exposure, credentials, or privileged service is introduced.
- The change only adjusts existing GC retention inputs.
- The GC service retains its existing sandboxing, locking, and maintenance-window coordination.

## Operational review

- Desktops gain a month-long rollback window without disabling GC.
- The minimum-generation rule prevents an inactive desktop from losing all rollback points.
- The policy is declarative and can be reverted independently.

## Validation

```bash
nix build .#checks.x86_64-linux.nix-gc-policy
nix build .#checks.x86_64-linux.nix-gc-observability
nix flake check
```

After deployment, verify that `navi` and `oryx` report 8 generations and a 30-day cutoff, while `r820`, `r730`, and `r730xd` remain at 4 generations and 14 days.
