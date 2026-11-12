# Stable package set audit

## Goal

Reduce unnecessary stable-channel evaluation and make stable-package usage explicit and narrowly scoped.

## Current state

`flake.nix` creates one shared `pkgs-stable` evaluation and passes it through `specialArgs` to every host and Home Manager configuration.

Current direct usage is limited to:

- `users/aljam/modules/desktop/apps.nix`: `pkgs-stable.lutris`
- `users/aljam/home-gui.nix`: imports the argument but does not currently use it in the indexed content
- `users/aljam/modules/desktop/kitty.nix`: imports the argument but does not currently use it in the indexed content

## Problem

Passing the entire stable package set to every module:

- Increases evaluation work.
- Makes it unclear which packages intentionally require the stable channel.
- Makes per-host overrides harder.
- Encourages accidental use of stable packages where unstable packages are sufficient.

## Proposed direction

Keep `nixpkgs-stable` as an input, but expose only the packages that genuinely require it through a small, named attribute set.

Example:

```nix
stablePackages = {
  lutris = pkgs-stable.lutris;
};
```

Then pass `stablePackages` through `specialArgs` instead of the full `pkgs-stable` set.

## Migration steps

1. Inventory every `pkgs-stable.*` reference.
2. Remove unused `pkgs-stable` function arguments.
3. Add only required packages to a curated `stablePackages` set.
4. Replace `pkgs-stable.<package>` references with `stablePackages.<package>`.
5. Keep the stable input pinned and document why each package needs it.

## Acceptance criteria

- No module receives the full `pkgs-stable` set unless it explicitly needs it.
- Every stable-package use is visible in one curated location.
- `nix flake check --no-build --print-build-logs` passes.
- `nix fmt -- --ci` passes.
