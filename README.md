# nixlab

[![CI](https://github.com/Aljam/nixlab/actions/workflows/ci.yml/badge.svg)](https://github.com/Aljam/nixlab/actions/workflows/ci.yml)
[![Security](https://github.com/Aljam/nixlab/actions/workflows/security.yml/badge.svg)](https://github.com/Aljam/nixlab/actions/workflows/security.yml)
[![License](https://img.shields.io/github/license/Aljam/nixlab?label=license)](LICENSE.md)
[![Flake](https://img.shields.io/badge/Nix-Flake-5277C3?logo=nixos&logoColor=white)](flake.nix)
[![SOPS](https://img.shields.io/badge/secrets-SOPS%20%2B%20age-2F855A?logo=gnuprivacyguard&logoColor=white)](https://github.com/getsops/sops)
[![Home Manager](https://img.shields.io/badge/Home-Manager-7EBF4B?logo=nix-community&logoColor=white)](https://github.com/nix-community/home-manager)

Declarative NixOS infrastructure for a multi-server homelab.

- Nix flakes for reproducible hosts
- sops-nix and age for service-scoped secrets
- NixOS tests and GitHub Actions CI
- HAProxy on pfSense as the public reverse-proxy gateway
- Prometheus, Grafana, and node_exporter for observability

## Quick Start

```bash
git clone https://github.com/aljam/nixlab.git
cd nixlab

# Build a host (replace <hostname> with navi, oryx, r730, r730xd, or r820)
sudo nixos-rebuild switch --flake .#<hostname>

# Run all evaluations and tests
nix flake check
```

## Hosts

| Host | Role | Primary services |
|---|---|---|
| `navi` | Desktop / daily driver | Hyprland, gaming, emulation |
| `oryx` | Laptop / development | Development, portable workstation |
| `r730` | Storage / AI | ZFS, PostgreSQL, remote builds |
| `r730xd` | Media / applications | Jellyfin, servarr, Vaultwarden, Matrix, PeerTube, monitoring |
| `r820` | Edge / data | Reverse-proxy backends, Grafana, PostgreSQL, distributed builds |

## Service catalogue

| Area | Services |
|---|---|
| Media | Jellyfin, Seerr, Audiobookshelf, PeerTube |
| Downloads | Sonarr, Radarr, Prowlarr, Bazarr, Lidarr, qBittorrent, Autobrr, Recyclarr |
| Identity / communication | Vaultwarden, Matrix Synapse, Matrix RTC |
| Monitoring | Prometheus, Grafana, Alertmanager, node_exporter, Blackbox exporter |
| Storage / backup | ZFS, Sanoid, Restic |
| Platform | PostgreSQL, Cachix, remote builders, static sites, radio/Icecast |

## Architecture

```text
nixlab/
├── flake.nix              # Entry point: mkHost helper, inputs, outputs
├── flake.lock             # Pinned dependencies
├── hosts/                 # Per-host configurations
├── modules/
│   ├── features/          # Reusable feature and service modules
│   ├── hardware/          # Hardware-specific modules
│   └── roles/             # Shared host roles
├── secrets/               # SOPS-encrypted secrets, split by service or trust boundary
├── tests/                 # NixOS tests
└── users/                 # User configurations
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Flake structure, mkHost, module organization
- [Secrets](docs/SECRETS.md) - Service-scoped SOPS files, SSH Ed25519 keys, host-key recovery
- [Runbook](docs/RUNBOOK.md) - Common operations, rollback, host-key recovery
- [Networking](docs/NETWORKING.md) - 192.168.1.x topology, HAProxy on pfSense, firewall rules

## Security model

- Services bind to loopback or explicit fleet service addresses.
- HAProxy is the only permitted source for reverse-proxied backend ports.
- Internal services are excluded from the HAProxy allowlist.
- SOPS secrets require an explicit file, owner, and `0400` mode.
- SSH is key-only; sudo requires a password.
- Remote PostgreSQL clients must use TLS.

## Development

### Prerequisites

- NixOS with flakes enabled
- Age key (host SSH Ed25519 key) for SOPS decryption
- Access to the Cachix binary cache (see [CACHIX.md](CACHIX.md))

### Running Checks

```bash
nix flake check
nix flake check --show-trace
nix fmt
```

The checks include firewall isolation, nftables input rules, administrative-service isolation, PostgreSQL authentication, and PostgreSQL LAN reachability.

### CI/CD

GitHub Actions runs on every push:

- Nix evaluation for all hosts
- Firewall security tests
- Formatting checks (nixfmt, statix, deadnix)
- Secret scanning (gitleaks)

## License

GPL-2.0 - see [LICENSE.md](LICENSE.md)
