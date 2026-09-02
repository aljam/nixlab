# nixlab

[![CI](https://github.com/Aljam/nixlab/actions/workflows/ci.yml/badge.svg)](https://github.com/Aljam/nixlab/actions/workflows/ci.yml)
[![Security](https://github.com/Aljam/nixlab/actions/workflows/security.yml/badge.svg)](https://github.com/Aljam/nixlab/actions/workflows/security.yml)
[![License](https://img.shields.io/github/license/Aljam/nixlab?label=license)](LICENSE.md)
[![Flake](https://img.shields.io/badge/Nix-Flake-5277C3?logo=nixos&logoColor=white)](flake.nix)
[![SOPS](https://img.shields.io/badge/secrets-SOPS%20%2B%20age-2F855A?logo=gnuprivacyguard&logoColor=white)](https://github.com/getsops/sops)
[![Home Manager](https://img.shields.io/badge/Home-Manager-7EBB4B?logo=nixos&logoColor=white)](https://github.com/nix-community/home-manager)

Declarative NixOS infrastructure for a multi-server homelab. Managed via flakes, sops-nix for secrets, and GitHub Actions for CI.

## Quick Start

```bash
# Clone and enter the repository
git clone https://github.com/aljam/nixlab.git
cd nixlab

# Build a host (replace <hostname> with navi, oryx, r730, r730xd, or r820)
sudo nixos-rebuild switch --flake .#<hostname>

# Run all evaluations and tests
nix flake check
```

## Hosts

| Host    | Role                                      | Hardware              |
|---------|-------------------------------------------|-----------------------|
| `navi`  | Desktop / daily driver (Hyprland, Steam)  | AMD Ryzen desktop     |
| `oryx`  | Laptop / development                      | System76 laptop       |
| `r730`  | ZFS storage / AI workloads | Dell PowerEdge R730 |
| `r730xd`| Media server / applications (Jellyfin, *arr, Vaultwarden) | Dell PowerEdge R730xd |
| `r820`  | Edge services / PostgreSQL / distributed build    | Dell PowerEdge R820   |

## Architecture

```
nixlab/
├── flake.nix              # Entry point: mkHost helper, inputs, outputs
├── flake.lock             # Pinned dependencies
├── hosts/                 # Per-host configurations
│   ├── navi/              # Desktop (hyprland, gaming, emulation)
│   ├── oryx/              # Laptop (System76, portable)
│   ├── r730/              # Storage server (ZFS, PostgreSQL, remote-builder)
│   ├── r730xd/            # Media/apps (Jellyfin, servarr, vaultwarden, prometheus)
│   └── r820/              # Edge (reverse-proxy-backends, grafana)
├── modules/               # Reusable NixOS modules
│   ├── features/          # Optional features (~30 flat .nix files)
│   ├── hardware/          # Hardware modules (dell-poweredge, navi-desktop, system76-laptop)
│   └── roles/             # Role modules (common, server-core, desktop-node, media-node, storage-node, ai-node, mail-node)
├── secrets/               # SOPS-encrypted secrets
│   └── secrets.yaml       # Single encrypted file for all hosts
├── tests/                 # NixOS tests
│   └── firewall.nix       # Security property tests
└── users/                 # User configurations
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Flake structure, mkHost, module organization
- [Secrets](docs/SECRETS.md) - SOPS with SSH Ed25519 keys, host-key recovery
- [Runbook](docs/RUNBOOK.md) - Common operations, rollback, host-key recovery
- [Networking](docs/NETWORKING.md) - 192.168.1.x topology, HAProxy on pfSense, firewall rules

## Development

### Prerequisites

- NixOS with flakes enabled
- Age key (host SSH Ed25519 key) for SOPS decryption
- Access to the Cachix binary cache (see [CACHIX.md](CACHIX.md))

### Running Tests

```bash
# Run all checks (evaluations + firewall test)
nix flake check

# Run only the firewall test
nix build .#checks.x86_64-linux.firewall
```

### Formatting

```bash
# Format all Nix files (nixfmt via treefmt)
nix fmt
```

### CI/CD

GitHub Actions runs on every push:

- Nix evaluation for all hosts
- Firewall security tests
- Formatting checks (nixfmt, statix, deadnix)
- Secret scanning (gitleaks)

## License

GPL-2.0 - see [LICENSE.md](LICENSE.md)
