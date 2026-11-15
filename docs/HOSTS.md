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
| `r730xd` | `modules/roles/server-core.nix`, `modules/roles/media-node.nix`, `modules/roles/storage-node.nix`, `modules/hardware/dell-poweredge.nix`, `modules/features/nvidia-headless.nix`; monitoring, backup, Loki, Restic, Matrix, static site, radio, PeerTube, and Vaultwarden features. | ZFS ARC maximum; ZFS host ID; systemd-resolved; Loki address; Grafana Loki URL; Restic jobs. | Primary application, media, monitoring, and backup host. |
| `r820` | `modules/roles/server-core.nix`, `modules/features/libvirt.nix`, `modules/features/postgres.nix`; mail role and module are intentionally commented out. | PostgreSQL databases, users, and client allowlists; PeerTube PostgreSQL extensions; Nix allowed users. | Database and virtualization host. |

## Role ownership

| Role | Responsibility | Status |
|---|---|---|
| `common.nix` | Fleet-wide baseline: boot, log shipping, networking options, Nix cache, SOPS, SSH, security policy, systemd hardening, audit logging, and automatic updates. | Active on all hosts. |
| `desktop-node.nix` | Desktop composition: audio, Bluetooth, graphics, Hyprland, emulation, NAS mount, networking tools, gaming, libvirt GUI, Flatpak, fonts, Gen1 recomp, and desktop portals. | Active on `navi` and `oryx`. |
| `server-core.nix` | Server baseline: node exporter, reverse-proxy backends, libvirt remote management, static networking, nftables, and Podman. | Active on `r730`, `r730xd`, and `r820`. |
| `media-node.nix` | Media and application service composition: homepage, Autobrr, Recyclarr, Vaultwarden, Grafana, Servarr, Matrix, static site, radio, and PeerTube. | Active on `r730xd`. |
| `storage-node.nix` | ZFS baseline and Sanoid snapshot policy. | Active on `r730` and `r730xd`. |
| `ai-node.nix` | Reserved future role for P40 GPU workloads. | Intentional TODO; not currently imported. |
| `mail-node.nix` | Implemented mail-server role using Postfix, Dovecot, ACME, and SendGrid relay. | Intentionally disabled on `r820`; retained for future re-enablement. |

## Infrastructure modules

| Module | Responsibility | Assessment |
|---|---|---|
| `deploy-user.nix` | Dedicated deployment identity and restricted rebuild boundary. | Active deployment control; keep unchanged. |
| `nix-builder.nix` | Restricted remote Nix builder identity and conditional distributed-build trust. | Conditional infrastructure; keep unchanged. |
| `host-baseline.nix` | Host health and security-posture metrics. | Active observability control; keep unchanged. |
| `security-policy.nix` | Cross-cutting invariants for SOPS ownership, proxy exposure, bind addresses, Recyclarr/Servarr, gaming/server exclusivity, and sudo. | Active policy control; keep unchanged. |
| `sops.nix` | `mkSecret` helper, explicit secret ownership, mandatory `0400` mode, and auditable root-owned exceptions. | Active secret baseline; keep unchanged. |
| `ssh.nix` | Key-only SSH, group access, forwarding restrictions, modern crypto, connection limits, and fail2ban. | Active access baseline; keep unchanged. |
| `systemd-hardening.nix` | Conservative opt-in systemd sandbox baseline for selected services. | Active hardening baseline; keep unchanged. |
| `networking-options.nix` | Fleet addressing, domains, monitoring host, proxy backend ports, and internal-only port policy. | Active networking contract; keep unchanged. |
| `nix-cache.nix` | Fleet-wide binary caches and paired trusted public keys. | Active build-cache baseline; keep unchanged. |
| `log-agent.nix` | Grafana Alloy journal shipping to Loki, with endpoint validation and least-privilege identity. | Active logging integration; keep unchanged. |
| `audit-logging.nix` | Kernel auditing, auditd, persistent journal, local retention, and disk bounds. | Active local audit baseline; keep unchanged. |
| `automatic-updates.nix` | Scheduled fleet flake evaluation and generation switch without automatic reboot. | Active update policy; keep unchanged. |
| `drift-monitoring.nix` | Configuration revision, nftables ruleset, critical-unit, and listener drift metrics. | Active drift detection; keep unchanged. |

## Reading path

1. Start at `hosts/<host>/configuration.nix`.
2. Follow its imported role and hardware modules.
3. Follow feature modules enabled by those roles.
4. Check `modules/features/sops.nix` and the relevant service module for secret
   consumers.
5. Check `tests/` and `flake.nix` for the applicable validation command.

## Intentional exceptions

- `ai-node.nix` is reserved for future P40 GPU workloads.
- `mail-node.nix` is implemented but intentionally disabled on `r820`.
- `storage-node.nix` is a valid minimal composition role for ZFS and Sanoid.
- `nix-builder.nix` only grants Nix daemon trust when distributed builds are
  explicitly enabled.

## Follow-up

- Keep this matrix current when host composition changes.
- Consider a follow-up refactor only if a role boundary becomes unclear.
- No infrastructure module inspected in this pass requires removal or
  restructuring.
