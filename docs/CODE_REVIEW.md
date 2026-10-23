# Infrastructure code review

This document records the main findings from a repository-wide review and the recommended follow-up work. The initial cleanup PR intentionally keeps functional changes small: it scopes the desktop-only overlay to desktop hosts, tightens fleet-network option types, and cleans up formatting in the common role.

## Strengths

- The flake has a clear host abstraction through `mkHost`, reducing duplication across `navi`, `oryx`, `r820`, `r730`, and `r730xd`.
- Most flake inputs follow the primary `nixpkgs` input, which reduces dependency drift and closure duplication.
- Secrets are managed with SOPS, and `.sops.yaml` includes per-host age recipients.
- The repository separates hosts, roles, hardware, features, users, secrets, and tests.
- The nftables rules test and firewall isolation VM test provide a useful safety net for networking changes.
- `reverse-proxy-backends.nix` centralizes HAProxy backend access and generates firewall rules from `networking.proxyBackendPorts`.

## High-priority follow-ups

### Scope shared package sets

`flake.nix` currently creates one shared `pkgs-stable` evaluation and passes it to every host and Home Manager configuration. This is convenient, but it increases evaluation work and makes per-host overrides harder.

Recommended approach:

- Keep `nixpkgs-stable` for packages that specifically require it.
- Expose only the needed stable packages through a curated attribute set, or construct stable packages within the host that uses them.
- Avoid passing an entire second `pkgs` set through `specialArgs` unless multiple modules need it.

### Keep overlays intentional

The CachyOS kernel overlay remains global because it may be relevant to multiple machines. The `artcraft` overlay is now applied only through `desktopModules`, keeping server hosts free of a desktop-oriented overlay.

When adding future overlays, prefer host- or feature-specific modules over `commonModules` unless every host genuinely needs them.

### Add feature-module switches

Several modules under `modules/features/` enable services as soon as they are imported. For reusable modules, add an explicit option such as:

```nix
options.nixlab.<feature>.enable = lib.mkEnableOption "<feature>";

config = lib.mkIf cfg.enable {
  # service configuration
};
```

This prevents accidentally enabling a media stack, database, monitoring service, or other infrastructure component merely by importing its module.

## Medium-priority follow-ups

### Strengthen networking metadata types

`networking.fleet`, `networking.subnets`, and `networking.domains` now use stricter attribute types. Further improvement could model fleet hosts with a submodule that explicitly distinguishes optional fields such as `ip` and `zpool`.

A typed host schema would catch malformed addresses, missing IPs, or unexpected fields during evaluation rather than at deployment time.

### Test critical services

The existing firewall tests are valuable. The next highest-value tests would cover:

- PostgreSQL starts, listens only on intended addresses, and accepts local authenticated connections.
- HAProxy backend ports are reachable only from the configured proxy address.
- Prometheus can reach enabled exporters, while other LAN clients cannot.
- Critical service units are active after a minimal server-host VM boot.
- Servarr services can create and read files under the shared media group.

### Clarify PostgreSQL exposure

`postgres.nix` enables TCP listening and includes the host fleet address in `listen_addresses`. The centralized firewall rules correctly restrict backend access to the HAProxy address, but this invariant should be protected by an integration test.

Consider documenting that `servicesBindAddress` is intended for gateway-reachable services, while loopback remains the default for hosts without a fleet IP.

## Low-priority follow-ups

- Consider moving `modules/features/gen1recomp.desktop` beside the package or desktop-entry definition that installs it.
- Add an architecture document describing host roles, module layering, secret rotation, and the intended test strategy.
- When adding non-x86_64 hosts, centralize the supported-system list instead of repeating `system` throughout the flake.
- Keep `flake.lock` updates deliberate, especially when changing the stable NixOS branch.
