# Architecture

This document describes the architecture of the nixlab NixOS configuration.

## Flake Structure

The flake is defined in `flake.nix` and provides:

- **Inputs**: `nixpkgs`, `nixpkgs-stable`, `sops-nix`, `home-manager`, and others
- **Outputs**:
  - `nixosConfigurations.<hostname>` - Full system configurations for each host
  - `checks.<system>.firewall` - NixOS test for firewall security properties
  - `checks.<system>.eval` - Fast evaluation check for all hosts
- **specialArgs**: `inputs`, `pkgs-stable`, and `hostname` passed to all modules

## Module Organization

### hosts/

Each host directory contains a `configuration.nix` that:

1. Imports shared modules from `modules/`
2. Declares host-specific hardware and role modules
3. Sets hostname and networking

Example (`hosts/navi/configuration.nix`):

```nix
{ config, pkgs, ... }:
{
  imports = [
    ../common.nix
    ../../modules/roles/desktop.nix
    ../../modules/hardware/amd-gpu.nix
  ];

  networking.hostName = "navi";
}
```

### modules/

#### modules/features/

Optional features that can be enabled on any host:

- `autobrr.nix` - Torrent automation
- `monitoring.nix` - Prometheus, Grafana, node-exporter
- `remote-builder.nix` - Distributed build support
- `media.nix` - Jellyfin, *arr services

#### modules/hardware/

Hardware-specific configurations:

- GPU drivers (AMD, Intel)
- Network interface tuning
- Storage controller modules

#### modules/roles/

Role-based configurations that define service profiles:

- `desktop.nix` - Hyprland, Steam, emulators
- `mail-node.nix` - Mail server stack
- `ai-node.nix` - ML/AI tooling
- `storage-node.nix` - ZFS, SMB/CIFS, backups

### users/

User configurations imported by hosts that need them:

- Declarative user accounts
- Home Manager configurations
- SSH and Git settings

## Secrets Management

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix). See [SECRETS.md](SECRETS.md) for details.

## Testing

### Firewall Tests

The `tests/firewall.nix` test verifies that:

- Backend services (qBittorrent WebUI, Vaultwarden) are not reachable from LAN
- node-exporter is only reachable from the monitoring host (r730)
- HAProxy correctly proxies external traffic to internal services

Run with:

```bash
nix build .#checks.x86_64-linux.firewall
```

### Evaluation Checks

The `eval` check ensures all hosts evaluate without errors:

```bash
nix build .#checks.x86_64-linux.eval
```

## Design Principles

1. **Declarative**: All configuration is in Nix; no manual edits on hosts
2. **Modular**: Features and roles are composable modules
3. **Tested**: Security properties are enforced by NixOS tests
4. **Minimal**: Only document what you maintain; delete drift
5. **Reproducible**: Pin dependencies via `flake.lock`; use Cachix for binary cache
