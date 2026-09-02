# Architecture

This document describes the high-level architecture of the NixLab flake.

## Directory Structure

```
.
├── flake.nix                 # Main entry point, defines mkHost helper
├── hosts/                    # Host-specific configurations
│   ├── navi/                 # Desktop workstation
│   ├── oryx/                 # Laptop
│   ├── r730/                 # Server (Dell R730)
│   ├── r730xd/               # Server (Dell R730 with different role)
│   └── r820/                 # Server (Dell R820)
├── modules/
│   ├── roles/                # Role profiles (common, server-core, media-node, etc.)
│   ├── features/             # Optional feature modules (servarr, vaultwarden, grafana, etc.)
│   └── hardware/             # Hardware-specific modules (Dell fans, etc.)
├── users/                    # User configurations (Home Manager + NixOS)
├── secrets/                  # SOPS-encrypted secrets
└── tests/                    # NixOS integration tests
```

## The mkHost Helper

The `flake.nix` defines a `mkHost` helper that reduces boilerplate for creating host configurations:

```nix
mkHost = { name, roles ? [], extraModules ? [] }:
  nixosLib.evalConfig {
    modules = [
      ./modules/roles/common.nix
      (map (role: ./modules/roles/${role}.nix) roles)
      extraModules
      { networking.hostName = name; }
    ];
  };
```

### Usage Example

```nix
# hosts/navi/configuration.nix
{ mkHost, ... }: mkHost {
  name = "navi";
  roles = [ "desktop-node" ];
  extraModules = [
    ./hardware-configuration.nix
    ../../users/aljam
    ../../modules/features/hyprland.nix
    ../../modules/features/audio.nix
  ];
}
```

### How It Works

1. **Base role**: Every host gets `modules/roles/common.nix` which sets up SSH, SOPS, fail2ban, locales, Cachix, and other fleet-wide defaults.

2. **Role composition**: The `roles` list imports role profiles from `modules/roles/`. For example, `server-core` adds node-exporter and reverse-proxy-backends; `media-node` adds the *arr stack, vaultwarden, and grafana.

3. **Extra modules**: Host-specific overrides and feature modules go in `extraModules`. This is where you add hardware configuration, user modules, and optional features.

4. **Hostname**: The `name` parameter sets `networking.hostName`.

## Roles

Roles are composable profiles that define a machine's purpose:

- **common.nix**: Base configuration applied to all hosts (SSH hardening, SOPS, fail2ban, etc.)
- **desktop-node.nix**: Desktop workstation features (Hyprland, audio, gaming, etc.)
- **server-core.nix**: Core server services (node-exporter, reverse-proxy-backends)
- **media-node.nix**: Media server stack (servarr, vaultwarden, grafana, postgres)
- **storage-node.nix**: Minimal storage server (ZFS, S.M.A.R.T. monitoring)
- **mail-node.nix**: Mail server (smtpd, dovecot, rspamd)
- **ai-node.nix**: AI/ML workstation (CUDA, NVIDIA drivers) - planned/future

## Features

Features are optional, flat modules in `modules/features/` that can be mixed into any host:

- **servarr.nix**: *arr stack (radarr, sonarr, prowarr, etc.)
- **vaultwarden.nix**: Password manager
- **grafana.nix** / **prometheus-server.nix**: Monitoring stack
- **reverse-proxy-backends.nix**: HAProxy backend configuration with firewall rules
- **networking-options.nix**: Centralized fleet networking (IPs, subnets, domains)
- And many more (see `modules/features/`)

## Networking Abstraction

The `networking-options.nix` module defines a central source of truth for fleet IPs, subnets, and domains. All services consume `config.networking.fleet`, `servicesBindAddress`, etc. rather than hardcoding IPs.

## Secrets

Secrets are managed with SOPS + age. Host SSH Ed25519 keys are used as age identities. See `docs/SECRETS.md` for details.

## Tests

The `tests/` directory contains NixOS integration tests:

- **nftables-shape.nix**: Eval-only test checking firewall rule structure
- **firewall-isolation.nix**: Full VM test proving only the gateway reaches backend ports and only Prometheus reaches node-exporter
