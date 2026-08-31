# Architecture

This document describes the architecture of the nixlab NixOS configuration.

## Flake Structure

The flake is defined in `flake.nix` and provides:

- **Inputs**: `nixpkgs` (unstable), `nixpkgs-stable`, `sops-nix`, `home-manager`, `treefmt-nix`, and others
- **Outputs**:
  - `nixosConfigurations.<hostname>` - Full system configurations for each host (navi, oryx, r730, r730xd, r820)
  - `checks.<system>.firewall` - NixOS test for firewall security properties
  - `checks.<system>.eval` - Fast evaluation check for all hosts
- **specialArgs**: `inputs`, `pkgs-stable`, and `hostname` passed to all modules

### mkHost Helper

The flake defines a `mkHost` helper that reduces boilerplate:

```nix
mkHost = name: modules: lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    sops-nix.nixosModules.sops
    ./modules/features
    ./modules/roles
    ./modules/hardware
    { networking.hostName = name; }
  ] ++ modules;
  specialArgs = { inherit inputs hostname; pkgs-stable = nixpkgs-stable.legacyPackages.system; };
};
```

## Module Organization

### hosts/

Each host directory contains:

- `configuration.nix` - Main configuration importing roles and features
- `hardware-configuration.nix` - Auto-generated hardware config
- `disko-config.nix` (servers only) - Disk layout for disko

Example (`hosts/r730/configuration.nix`):

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ../../modules/roles/common.nix
    ../../modules/roles/server-core.nix
    ../../modules/roles/storage-node.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/features/postgres.nix
    ../../modules/features/remote-builder.nix
    ../../modules/features/sanoid.nix
  ];

  networking.hostName = "r730";
}
```

### modules/roles/

Role modules define service profiles:

| Module | Purpose |
|--------|---------|
| `common.nix` | Base system settings (timeouts, gc, journald limits, sops, users) |
| `server-core.nix` | Server hardening (firewall, ssh, fail2ban, auto updates) |
| `desktop-node.nix` | Desktop base (pipewire, fonts, flatpak, user config) |
| `media-node.nix` | Media stack (jellyfin, servarr, autobrr) |
| `storage-node.nix` | ZFS utilities (zfs, samba, nfs, smartmontools) |
| `ai-node.nix` | ML/AI tooling (cuda, ollama) |
| `mail-node.nix` | Mail server (postfix, dovecot) |

### modules/features/

Flat feature modules (~30 files) that can be mixed into any host:

- **Core services**: `postgres.nix`, `vaultwarden.nix`, `grafana.nix`, `prometheus-server.nix`, `prometheus-alerts.nix`, `node-exporter.nix`
- **Media**: `servarr.nix`, `recyclarr.nix`, `youtube.nix`, `jellyfin` (via media-node)
- **Desktop**: `hyprland.nix`, `gaming.nix`, `emulation.nix`, `flatpak.nix`, `audio.nix`, `bluetooth.nix`, `fonts.nix`, `graphics.nix`
- **Infrastructure**: `remote-builder.nix`, `libvirt.nix`, `nas-mount.nix`, `sanoid.nix`, `zfs-base.nix`, `homepage.nix`, `reverse-proxy-backends.nix`
- **Hardware support**: `nvidia-headless.nix`, `boot.nix`

### modules/hardware/

Hardware-specific modules:

| Module | Hosts | Purpose |
|--------|-------|---------|
| `dell-poweredge.nix` | r730, r730xd, r820 | IPMI, power management, RAID monitoring |
| `navi-desktop.nix` | navi | AMD GPU, desktop peripherals |
| `system76-laptop.nix` | oryx | Laptop-specific tuning, power management |

### users/

User configurations imported by hosts:

- Declarative user accounts (`users.users.aljam`)
- Home Manager configurations
- SSH and Git settings

## Secrets Management

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix). See [SECRETS.md](SECRETS.md) for details.

**Key points:**

- Single `secrets/secrets.yaml` encrypted file for all hosts
- Age identities are host SSH Ed25519 keys (`/etc/ssh/ssh_host_ed25519_key`)
- `neededForUsers = true` for `aljam_password` (required for mutableUsers = false)
- Changing host keys breaks decryption until `sops updatekeys` is run

## Testing

### Firewall Tests

The `tests/firewall.nix` test verifies that:

- Backend services (qBittorrent WebUI, Vaultwarden) are not reachable from LAN
- node-exporter is only reachable from the monitoring host (r730xd)
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
2. **Modular**: Roles and features are composable; flat structure in `modules/features/`
3. **Tested**: Security properties are enforced by NixOS tests
4. **Minimal**: Only document what you maintain; delete drift
5. **Reproducible**: Pin dependencies via `flake.lock`; use Cachix for binary cache
