# Flake inventory

This document inventories the Nix flake inputs and outputs used by Nixlab.

## Inspect the flake

Run:

```bash
nix flake show
```

This displays the flake’s host configurations, packages, checks, and apps.

For machine-readable output:

```bash
nix flake show --json
```

## Inputs

| Input | Purpose | Nixpkgs policy |
|---|---|---|
| `nixpkgs` | Primary unstable Nixpkgs input | Source of truth |
| `nixpkgs-stable` | Stable Nixpkgs for selected packages | Independent stable channel |
| `nix-cachyos-kernel` | CachyOS kernel support | Follows `nixpkgs` |
| `nixos-hardware` | Hardware-specific NixOS modules | Follows `nixpkgs` |
| `artcraft` | Artcraft package/overlay | Follows `nixpkgs` |
| `sops-nix` | SOPS secret management | Follows `nixpkgs` |
| `home-manager` | Home Manager | Follows `nixpkgs` |
| `disko` | Declarative disk partitioning | Follows `nixpkgs` |
| `nix-flatpak` | Flatpak management | Independent upstream input |
| `hyprland` | Hyprland desktop environment | Follows `nixpkgs` |
| `nur` | Nix User Repository | Follows `nixpkgs` |

## Host configurations

| Output | Host | Role |
|---|---|---|
| `nixosConfigurations.navi` | `navi` | Desktop |
| `nixosConfigurations.oryx` | `oryx` | Desktop |
| `nixosConfigurations.r820` | `r820` | Server |
| `nixosConfigurations.r730` | `r730` | Server |
| `nixosConfigurations.r730xd` | `r730xd` | Server |

## Packages

| Output | Purpose |
|---|---|
| `packages.x86_64-linux.firewall-isolation` | Firewall isolation test package |
| `packages.x86_64-linux.admin-isolation` | Administrative isolation test package |

## Checks

The `checks.x86_64-linux` output contains the repository’s NixOS integration,
isolation, recovery, monitoring, security, and deployment tests.

Run all checks with:

```bash
nix flake check --show-trace
```

Run one check:

```bash
nix run .#checks.x86_64-linux.<check-name>
```

## Apps

| App | Purpose |
|---|---|
| `apps.x86_64-linux.deploy` | Deploy the current `origin/main` revision to selected hosts |
| `apps.x86_64-linux.deploy-plan` | Validate and print the deployment plan without connecting or switching |
| `apps.x86_64-linux.deploy-status` | Report whether deploy hosts run the current `origin/main` revision |

## Formatter

Format Nix files with:

```bash
nix fmt
```

Verify formatting without changing files:

```bash
nix fmt -- --ci
```
