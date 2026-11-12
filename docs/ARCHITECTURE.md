# Architecture

This document describes the high-level architecture of the NixLab flake.

## Directory structure

```text
.
|-- flake.nix                 # Entry point: host construction, shared modules, checks
|-- flake.lock                # Pinned dependencies
|-- hosts/                    # Host-specific configurations
|   |-- navi/                 # Desktop workstation
|   |-- oryx/                 # Laptop
|   |-- r730/                 # Storage / AI server
|   |-- r730xd/               # Media / applications server
|   `-- r820/                 # Database / edge server
|-- modules/
|   |-- roles/                # Reusable host-role profiles
|   |-- features/             # Optional feature and service modules
|   `-- hardware/             # Hardware-specific modules
|-- users/                    # User and Home Manager configurations
|-- secrets/                  # SOPS-encrypted secrets
`-- tests/                    # Evaluation checks and NixOS VM tests
```

## Host construction

`flake.nix` defines `mkHost` to reduce boilerplate across the fleet:

```nix
mkHost =
  {
    hostname,
    extraModules ? [ ],
  }:
  lib.nixosSystem {
    inherit system;

    specialArgs = {
      inherit inputs pkgs-stable hostname;
    };

    modules =
      commonModules { inherit hostname; }
      ++ [
        ./hosts/${hostname}/configuration.nix
        ./users/aljam/nixos.nix
        {
          system.configurationRevision = self.rev or self.dirtyRev or "";
        }
      ]
      ++ extraModules;
  };
```

A host is declared in `flake.nix` by its hostname and optional extra modules:

```nix
navi = mkHost {
  hostname = "navi";
  extraModules = desktopModules;
};
```

Hosts do **not** pass a list of roles to `mkHost`. Instead, each host
configuration imports the role modules it needs directly.

## Shared configuration

`commonModules` supplies configuration required by every host:

- The common role, `modules/roles/common.nix`.
- The deployment user policy, `modules/features/deploy-user.nix`.
- The sops-nix NixOS module.
- Home Manager.
- The `aljam` user configuration.
- The deployment-user enablement option.

The flake also sets `system.configurationRevision` from the current Git
revision, or dirty revision when working from an uncommitted tree.

## Host composition

Host-specific configuration lives in `hosts/<hostname>/configuration.nix`.
Those files import the hardware, role, and feature modules appropriate for
that machine.

For example, `r730` imports:

```nix
./hardware-configuration.nix
./disko-config.nix
../../modules/hardware/dell-poweredge.nix
../../modules/roles/server-core.nix
../../modules/roles/storage-node.nix
../../modules/features/nvidia-headless.nix
```

`r820` imports its own hardware, server-core, libvirt, PostgreSQL, and
remote-builder configuration. Desktop hosts receive the shared
`desktopModules` set, which includes desktop-oriented overlays and Home
Manager GUI configuration.

## Roles

Roles are composable host profiles in `modules/roles/`:

- `common.nix`: Fleet-wide baseline configuration.
- `server-core.nix`: Core server services and monitoring integration.
- `media-node.nix`: Media-server role.
- `storage-node.nix`: ZFS and storage-oriented configuration.
- `mail-node.nix`: Mail-server role.
- `ai-node.nix`: Reserved AI/ML workstation role.

A host may import multiple roles. Role modules should describe a machine
purpose, while feature modules should provide a focused, reusable capability.

## Features

Feature modules live in `modules/features/`. They provide discrete services
and capabilities, such as:

- `servarr.nix`
- `vaultwarden.nix`
- `grafana/`
- `prometheus-server.nix`
- `postgres.nix`
- `restic-backup.nix`
- `reverse-proxy-backends.nix`
- `networking-options.nix`

Feature modules are intended to be composable. Hosts explicitly import the
features they require; shared infrastructure is centralized rather than
implemented separately on every host.

## Networking

`modules/features/networking-options.nix` is the central source of truth for
fleet hosts, subnets, and domains. Services consume `config.networking.fleet`,
`config.networking.servicesBindAddress`, and related options rather than
hardcoding addresses.

`servicesBindAddress` is intended for services that must be reachable through
the fleet network or HAProxy gateway. Services that do not need fleet
reachability should bind to loopback.

## Secrets

Secrets are managed with SOPS and age. Host SSH Ed25519 keys are used as age
identities, and `.sops.yaml` defines explicit recipient sets for each secret
file.

See [Secrets](SECRETS.md) for the recipient model, recovery procedure, and
recipient-change workflow.

## Tests

The `tests/` directory contains evaluation checks and NixOS VM tests.
`tests/README.md` documents what each check covers.

Flake checks run through `nix flake check`:

- `nftables-input-rules`
- `service-exposure`
- `public-service-hardening`
- `public-endpoint-inventory`
- `monitoring-health`
- `postgresql-auth`

Slower VM tests are exposed as flake packages and run by the VM-test workflow:

- `firewall-isolation`
- `admin-isolation`

```bash
nix flake check
nix build --print-build-logs .#firewall-isolation .#admin-isolation
```
