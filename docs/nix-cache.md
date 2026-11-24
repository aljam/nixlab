# Nix binary-cache policy

All Nix substituters and trusted public keys are configured in
`modules/features/nix-cache.nix`.

## Rules

- Every substituter URL must use HTTPS.
- Every substituter must have a trusted public key.
- Public keys must be copied from the cache operator’s authoritative documentation; never guess or reuse another cache’s key.
- Do not add a substituter directly in a host or role module.
- Remove a cache when it is no longer needed; unused caches increase trust surface and can create confusing substitution failures.

## Current caches

| Cache | Scope | Notes |
|---|---|---|
| `cache.nixos.org` | All hosts | Official NixOS binary cache. |
| `aljam.cachix.org` | All hosts | Fleet-owned cache; CI pushes host closures after builds on `main`. |
| `nix-community.cachix.org` | All hosts | Community cache. |
| `nix-gaming.cachix.org` | All hosts | Gaming dependencies; key verified from the upstream `fufexan/nix-gaming` README. |
| `hyprland.cachix.org` | All hosts | Hyprland flake dependencies; key verified from the Hyprland wiki. |

## Adding a cache

1. Obtain the cache URL and public key from the operator.
2. Add both to the `caches` attribute set in `modules/features/nix-cache.nix`.
3. Run `nix flake check --no-build` and inspect the resulting `nix.settings` values.
4. If CI needs to pull from it, add its Cachix name to `extraPullNames` in the CI workflows.
5. Open a PR and ensure evaluation succeeds before merging.

## Cache warming

Use **Actions → Cache warm → Run workflow** before a fleet rollout or after a substantial
`flake.lock` update. It builds every host and pushes its closure to `aljam.cachix.org`.

Normal pull requests intentionally evaluate configurations without building or pushing closures.
