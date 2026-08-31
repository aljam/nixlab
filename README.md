# nixlab

Declarative NixOS infrastructure for a multi-server homelab. Managed via flakes, sops-nix for secrets, and GitHub Actions for CI.

[![Nix](https://img.shields.io/badge/NixOS-unstable-blue)](https://nixos.org)
[![SOPS](https://img.shields.io/badge/Secrets-SOPS-green)](https://github.com/Mic92/sops-nix)

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

| Host    | Role                          | Hardware                    |
|---------|-------------------------------|-----------------------------|
| `navi`  | Desktop / daily driver        | AMD Ryzen, Hyprland, Steam  |
| `oryx`  | Laptop / development          | System76                    |
| `r730`  | Storage / ZFS / media         | Dell R730, ZFS              |
| `r730xd`| Application server / services | Dell R730                   |
| `r820`  | Edge / reverse proxy          | Dell R820                   |

## Architecture

```
nixlab/
├── flake.nix              # Entry point: inputs, outputs, specialArgs
├── flake.lock             # Pinned dependencies
├── hosts/                 # Per-host configurations
│   ├── navi/
│   ├── oryx/
│   ├── r730/
│   ├── r730xd/
│   └── r820/
├── modules/               # Reusable NixOS modules
│   ├── features/          # Optional features (autobrr, monitoring, etc.)
│   ├── hardware/          # Hardware-specific modules
│   └── roles/             # Role-based configurations (mail, ai-node, etc.)
├── secrets/               # SOPS-encrypted secrets
│   └── secrets.yaml
├── tests/                 # NixOS tests and assertions
│   └── firewall.nix       # Security property tests
└── users/                 # User configurations
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Flake structure, module organization, evaluation model
- [Secrets](docs/SECRETS.md) - SOPS setup, encryption, adding new secrets
- [Runbook](docs/RUNBOOK.md) - Common operations, rebuild commands, troubleshooting
- [Networking](docs/NETWORKING.md) - Network topology, subnets, firewall rules

## Development

### Prerequisites

- NixOS with flakes enabled
- Age key for SOPS (see [docs/SECRETS.md](docs/SECRETS.md))
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
# Format all Nix files
nix fmt

# Format with nixfmt (RFC-style)
nix run nixpkgs#nixfmt
```

### CI/CD

GitHub Actions runs on every push:

- Nix evaluation for all hosts
- Firewall security tests
- Formatting checks (nixfmt, statix, deadnix)
- Secret scanning (gitleaks)

## License

MIT - see [LICENSE.md](LICENSE.md)
