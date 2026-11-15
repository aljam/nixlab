# Host feature traceability

This matrix maps hosts to the roles and feature modules that define their
behavior. It is intended to make it easier to answer:

- Which features does a host enable?
- Which module owns a setting?
- Which host uses a service or secret?
- Which test validates a feature?

The authoritative configuration remains the Nix module tree. This document is
a navigation aid and should be updated when host composition changes.

## Hosts

| Host | Imported roles and hardware | Host-specific settings | Feature traceability |
|---|---|---|---|
| `navi` | `modules/roles/desktop-node.nix`, `modules/hardware/navi-desktop.nix` | `programs.corectrl.enable = true` for AMD overclocking and undervolting. | Desktop node; inspect `desktop-node.nix` for the enabled feature set. |
| `oryx` | `modules/roles/desktop-node.nix`, `modules/hardware/system76-laptop.nix` | None beyond the shared desktop role and System76 hardware module. | Desktop node; inspect `desktop-node.nix` for the enabled feature set. |
| `r730` | `modules/roles/server-core.nix`, `modules/roles/storage-node.nix`, `modules/hardware/dell-poweredge.nix`, `modules/features/nvidia-headless.nix` | ZFS host ID; CUDA toolkit package. | Server and storage node with NVIDIA headless support. |
| `r730xd` | Pending inspection | Pending inspection | Pending inspection. |
| `r820` | Pending inspection | Pending inspection | Pending inspection. |

## Reading path

1. Start at `hosts/<host>/configuration.nix`.
2. Follow its imported role and hardware modules.
3. Follow feature modules enabled by those roles.
4. Check `modules/features/sops.nix` and the relevant service module for secret
   consumers.
5. Check `tests/` and `flake.nix` for the applicable validation command.

## Pending work

- Complete traceability for `r730xd` and `r820`.
- Identify feature modules that are enabled but unreachable.
- Identify duplicated host or role configuration.
- Map each meaningful feature to a test or documented validation command.
