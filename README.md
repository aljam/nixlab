# nixlab

[![CI](https://github.com/Aljam/nixlab/actions/workflows/ci.yml/badge.svg)](https://github.com/Aljam/nixlab/actions/workflows/ci.yml)
[![Security](https://github.com/Aljam/nixlab/actions/workflows/security.yml/badge.svg)](https://github.com/Aljam/nixlab/actions/workflows/security.yml)
[![License](https://img.shields.io/github/license/Aljam/nixlab?label=license)](LICENSE.md)
[![Flake](https://img.shields.io/badge/Nix-Flake-5277C3?logo=nixos&logoColor=white)](flake.nix)
[![SOPS](https://img.shields.io/badge/secrets-SOPS%20%2B%20age-2F855A?logo=gnuprivacyguard&logoColor=white)](https://github.com/getsops/sops)
[![Home Manager](https://img.shields.io/badge/Home-Manager-7EBB4B?logo=nixos&logoColor=white)](https://github.com/nix-community/home-manager)

One Nix flake that defines five machines: two workstations and a three-node Dell PowerEdge rack. Kernels, ZFS pool topology, services, firewall rules, dotfiles, and encrypted secrets all live here — nothing is configured by hand on a host.

`x86_64-linux` only · nixpkgs `nixos-unstable` (with `nixos-25.11` as `pkgs-stable`) · Home Manager · Disko · sops-nix · `stateVersion` `26.05`

## Fleet

| Host | Hardware | Composition | What it actually runs |
| :--- | :--- | :--- | :--- |
| `navi` | Custom AMD desktop | `desktop-node` + `navi-desktop` | Primary workstation. Plasma 6 on SDDM plus Hyprland, CachyOS LTS kernel, Steam/gaming, libvirt, emulation, Flatpak, CoreCtrl. Offloads builds to `r820`. |
| `oryx` | System76 laptop | `desktop-node` + `system76-laptop` + `nixos-hardware.system76` | Portable workstation, same desktop stack. NVIDIA PRIME sync, System76 firmware/power daemons, `system76-scheduler`, `fwupd`. |
| `r730` | Dell PowerEdge R730 | `server-core` + `storage-node` + `dell-poweredge` + Disko | ZFS host on `r730pool`, kernel pinned to 6.1, Podman. Staged for AI/GPU work — see [Staged, not active](#staged-not-active). |
| `r730xd` | Dell PowerEdge R730xd (24-bay) | `server-core` + `media-node` + `storage-node` + `nvidia-headless` + `prometheus-server` + `dell-poweredge` + Disko | The workhorse. Full media stack, Vaultwarden, Prometheus + Grafana, Tesla P40 (legacy 535 driver) for Jellyfin transcoding, `mediapool`. |
| `r820` | Dell PowerEdge R820 (quad-socket) | `server-core` + `libvirt` + `postgres` + `dell-poweredge` | PostgreSQL + pgAdmin, libvirt, and the distributed Nix builder for both workstations (`maxJobs = 32`, `speedFactor = 2`). |

### Network

Addresses, ZFS pool names, and the seven domains are declared once in `modules/features/networking-options.nix` and consumed through `config.networking.{fleet,subnets,domains,myDomain}`, so no module hardcodes an IP or hostname. `networking.servicesBindAddress` (defined in `common.nix`) resolves to the host's own fleet IP, or `127.0.0.1` on machines with no fleet entry — that single option is what every service binds to.

| Host | Address | ZFS pool |
| :--- | :--- | :--- |
| `r730xd` | `192.168.1.2` | `mediapool` |
| `r730` | `192.168.1.3` | `r730pool` |
| `r820` | `192.168.1.4` | — (hardware RAID) |
| pfSense gateway / DNS / HAProxy | `192.168.1.1` | — |
| NAS (CIFS) | `192.168.2.10` | — |

Servers take a static address on `eno1`, disable NetworkManager and IPv6, and run nftables with `192.168.1.1` as both gateway and primary resolver. `navi` and `oryx` use NetworkManager and reach the rack over Tailscale (`useRoutingFeatures = "both"`, `--accept-routes`) when off-LAN. Primary domain is `derezzed.info`.

## Layout

```text
nixlab/
├── flake.nix                     # inputs, mkHost, the five host outputs
├── .sops.yaml                    # age recipients: your key + all five host keys
├── secrets/secrets.yaml          # single sops-encrypted file for the whole fleet
├── .github/workflows/            # ci.yml, cachix.yml, security.yml
├── .gitleaks.toml
├── hosts/
│   ├── navi/, oryx/              # configuration + hardware-configuration
│   ├── r730/                     # + disko-config.nix — 4 × 2-disk mirrors
│   ├── r730xd/                   # + disko-config.nix — 3 × 8-disk raidz2
│   └── r820/
├── modules/
│   ├── roles/                    # common, server-core, desktop-node, storage-node,
│   │                             # media-node, ai-node, mail-node
│   ├── features/                 # one concern per file — services, desktop bits, monitoring
│   └── hardware/                 # dell-poweredge, navi-desktop, system76-laptop
├── users/aljam/                  # nixos.nix, home.nix, home-gui.nix, modules/{core,desktop}
├── tests/                        # NixOS VM tests (see caveat under Known gaps)
└── docs/                         # ARCHITECTURE, SETUP, SECRETS, ROLES, NETWORKING, …
```

### How a host is composed

`mkHost` in `flake.nix` gives every machine the same base, then layers roles and features on top:

```
hosts/<name>/configuration.nix
  └─ modules/roles/common.nix         always — hostname, locale, SSH, sops, nix.settings
       ├─ features/boot.nix           GRUB (EFI, nodev, 10 generations), fleet-wide
       └─ features/networking-options.nix   the fleet/domains/subnets tables
  └─ modules/roles/{desktop-node|server-core}.nix
       └─ modules/features/*.nix      audio, hyprland, jellyfin, sonarr, grafana, …
  └─ modules/hardware/<machine>.nix
  └─ users/aljam/{nixos.nix,home.nix}
```

`mkHost` also wires in sops-nix, NUR, the pinned CachyOS kernel overlay, and Home Manager (`useGlobalPkgs`, `useUserPackages`), passing `inputs`, `pkgs-stable`, and `hostname` through `specialArgs` and `extraSpecialArgs`. Workstations add a `desktop` module (`home-gui.nix`) and `nix-flatpak`.

The `aljam` account resolves its supplementary groups defensively — `wheel`/`video`/`render`/`input` always, plus `networkmanager`, `libvirtd`, `wireshark`, `media`, and `podman` only where those groups exist — so one user module is safe on both desktops and servers.

**Roles**

| Module | Applies to | Provides |
| :--- | :--- | :--- |
| `common.nix` | all five | GRUB, `stateVersion`, `America/Toronto` + `en_CA.UTF-8`, flakes, `cache.nixos.org` plus five Cachix substituters, sops (age via `/etc/ssh/ssh_host_ed25519_key`), SSH hardened to key-only `aljam`/`wheel`, fail2ban, `mutableUsers = false`, base CLI tools |
| `server-core.nix` | the rack | static `eno1`, no NetworkManager, no IPv6, nftables, gateway/DNS from `fleet.proxy`, ports 80/443, Podman (`dockerCompat` + Docker socket), smartd, node-exporter, Alertmanager, proxy backend firewall |
| `desktop-node.nix` | `navi`, `oryx` | CachyOS LTS kernel, NetworkManager, Tailscale, KDE Connect, audio/bluetooth/graphics/Hyprland, fonts, gaming, emulation, libvirt, Flatpak, networking tools, NAS mount, remote builder |
| `storage-node.nix` | `r730`, `r730xd` | ZFS weekly scrub + sanoid snapshots |
| `media-node.nix` | `r730xd` | the `media` user/group, its `/var/lib` tmpfiles, and every media service below |

## Services

All on `r730xd` unless noted. Every daemon binds `networking.servicesBindAddress` rather than `0.0.0.0`, and each feature module appends its own port to `networking.proxyBackendPorts`; `reverse-proxy-backends.nix` turns that list into a single nftables rule accepting those ports **only** from HAProxy at `192.168.1.1`.

| Service | Port | Notes |
| :--- | :--- | :--- |
| Jellyfin | 8096 | `media` group; NVENC via `nvidia-headless.nix` |
| Sonarr / Radarr | 8989 / 7878 | API keys from sops, consumed by Recyclarr |
| Prowlarr / Bazarr / Lidarr | 9696 / 6767 / 8686 | |
| Recyclarr | — | TRaSH Guides sync for Sonarr and Radarr profiles |
| Shoko | 8111 | AniDB metadata |
| Jellyseerr (`services.seerr`) | 5055 | |
| Audiobookshelf | 13378 | |
| Autobrr | 7474 | IRC announce filtering, API key from sops |
| qBittorrent | 8080 web / 6881 peer | Only 6881 TCP+UDP is open to the internet; the WebUI is proxy-only |
| ytdl-sub | — | Timer every 30 min, downloads to `/mnt/media/youtube`; PO-token provider (`bgutil`) runs as a Podman container on `127.0.0.1:4416` |
| Vaultwarden | 8222 | `signupsAllowed = false`, admin token from sops, admin rate limiting, `https://vault.derezzed.info` |
| homepage-dashboard | 8082 | `allowedHosts = home.derezzed.info`; links the `https://*.derezzed.info` names |
| Prometheus | 9090 | 15 s scrape/eval interval |
| Alertmanager | 9093 | on **every** server via `server-core` |
| Grafana | 3000 | admin password + secret key from sops via `$__file{}` |
| node-exporter | 9100 | on every server; opened only to `192.168.1.2`; systemd/cpu/diskstats/filesystem/netdev/zfs/hwmon/nvme collectors |
| PostgreSQL / pgAdmin | 5432 / 5050 | **`r820`** — scram-sha-256, listening on localhost + its fleet IP, `webscraper` + `admin` databases; only 5050 is a proxy backend |
| Ollama / Open WebUI | 11434 / 8085 | **`r730`** — staged, not enabled |

### Ingress

TLS terminates at HAProxy on the pfSense gateway, which is **not** managed by this repository. What lives here is the other half of that contract: services bind one specific address, `proxyBackendPorts` declares what the proxy may reach, and Grafana, Vaultwarden, and homepage-dashboard are configured with their public `https://*.derezzed.info` origins so redirects, cookies, and Host-header validation line up behind the proxy.

The practical consequence: none of the above is reachable directly from another LAN host. If a service seems unreachable by IP and port, the firewall is working as designed — go through the proxy name, or add the source address explicitly.

## Storage

Both ZFS hosts are provisioned declaratively with [Disko](https://github.com/nix-community/disko), so a bare-metal reinstall reproduces partitioning, pool topology, and datasets with no manual `zpool create`. Each uses a dual-ESP layout (`/boot`, `/boot2`) on the first two disks.

- **`r730` — `r730pool`:** four 2-disk mirror vdevs, `lz4`, datasets `root` → `/`, `nix` → `/nix`, `home` → `/home`.
- **`r730xd` — `mediapool`:** three 8-disk raidz2 vdevs, `zstd`, datasets `root` → `/`, `media` → `/mnt/media`. ARC capped at 64 GiB via `zfs.zfs_arc_max`.

Scrubs run Sunday 02:00 on both pools. Sanoid checks every 15 minutes and keeps 24 hourly, 7 daily, and 3 monthly snapshots with autoprune — but only for `mediapool/root` and `mediapool/media`.

## Secrets

One `sops`-encrypted file, `secrets/secrets.yaml`, encrypted to your key plus the age-converted SSH host key of all five machines. Each host decrypts at activation from `/etc/ssh/ssh_host_ed25519_key`, so nothing depends on an unlocked user keyring.

| Key | Consumer |
| :--- | :--- |
| `aljam_password` | login / sudo (`neededForUsers = true`, `mkpasswd -m yescrypt`) |
| `nas-credentials` | CIFS mount at `/mnt/share` |
| `sonarr_api_key`, `radarr_api_key` | Recyclarr |
| `autobrr_api_key` | Autobrr |
| `grafana-admin-password`, `grafana-secret-key` | Grafana |
| `pgadmin_password` | pgAdmin |
| `vaultwarden-admin-token` | Vaultwarden |
| `vaultwarden-smtp-username`, `vaultwarden-smtp-password` | unused — no SMTP config wired yet |
| `alertmanager_smtp_password` | unused — see [Known gaps](#known-gaps) |
| `restic-password` | unused — no backup module |

```bash
sops secrets/secrets.yaml               # edit
sops updatekeys secrets/secrets.yaml    # after changing recipients in .sops.yaml
```

> `users.mutableUsers = false` fleet-wide means passwords come **only** from `hashedPasswordFile`. If a host's SSH host key is regenerated it can no longer decrypt `aljam_password` — no console login, no `sudo`. Re-run `sops updatekeys` and rebuild before rebooting after any host-key change.

## Usage

Requires Nix with `experimental-features = nix-command flakes`.

```bash
# build and switch locally
sudo nixos-rebuild switch --flake .#navi

# push to a rack node
nixos-rebuild switch --flake .#r730xd --target-host aljam@192.168.1.2 --use-remote-sudo

# validate before deploying
nix flake check --all-systems --show-trace
nix build --no-link '.#nixosConfigurations.r730xd.config.system.build.toplevel'
nixos-rebuild build --flake .#r730xd && nix run nixpkgs#nvd -- diff-closure /run/current-system result

# formatting (CI enforces this)
nix fmt

# VM tests
nix-build tests/default.nix

# inputs
nix flake update                # all
nix flake update nixpkgs        # one
```

Both workstations use `r820` as a distributed builder over SSH, so large rebuilds are offloaded automatically. This depends on root's key at `/root/.ssh/id_ed25519` on the client and `aljam` being a trusted user on `r820`.

### First install on new hardware

```bash
# from the installer, with this flake available
sudo nix run github:nix-community/disko -- --mode disko --flake .#r730xd
sudo nixos-install --flake .#r730xd

# then enroll the new host key as a secrets recipient
ssh-keyscan -t ed25519 <host> | ssh-to-age    # add to .sops.yaml
sops updatekeys secrets/secrets.yaml
```

### CI

| Workflow | Trigger | Does |
| :--- | :--- | :--- |
| `ci.yml` | push to `main`, all PRs | `nix flake check --all-systems`, `nix fmt` diff check, then a build matrix — `navi` only on PRs, all five hosts on push |
| `cachix.yml` | push to `main`, manual | Builds `r730`/`r730xd`/`r820` closures and pushes them to the `aljam` Cachix cache; manual runs take a single host input |
| `security.yml` | — | Gitleaks over tracked files and full Git history, plus `nix flake check` |

## Documentation

Deeper guides live in [`docs/`](docs/): [Architecture](docs/ARCHITECTURE.md), [Getting Started](docs/GETTING-STARTED.md), [Setup](docs/SETUP.md), [Secrets](docs/SECRETS.md), [Roles](docs/ROLES.md), [Networking](docs/NETWORKING.md), [Backup & Recovery](docs/BACKUP-RECOVERY.md), [Deployment Checklist](docs/DEPLOYMENT-CHECKLIST.md), [Alerts](docs/ALERTS.md), and [Cachix](CACHIX.md). Where a guide and the Nix source disagree, the source wins.

## Staged, not active

Present in the tree but deliberately not imported. Enabling any of these needs the listed work.

| Module | Status |
| :--- | :--- |
| `modules/roles/ai-node.nix` | Ollama + Open WebUI for the Tesla P40s in `r730`. Needs `acceleration = "cuda"`, `nixpkgs.config.cudaSupport`, and `nvidia-container-toolkit` uncommented — expect a long from-source rebuild. |
| `modules/features/nvidia-headless.nix` on `r730` | Commented out alongside `ai-node`. `r730` still installs `cudatoolkit` and `linuxPackages.nvidia_x11`, and the latter targets the default kernel while the host pins `linuxPackages_6_1`. |
| `modules/roles/mail-node.nix` | Imported nowhere. Needs `mailserver.nixosModules.mailserver` in the module list and `smtp_relay_password` + `mail_password_aljam` added to `secrets.yaml`. |
| `modules/features/nas-mount.nix` on `r730xd` | Commented out in `media-node.nix`; still active on both workstations. |

## Known gaps

Tracked here rather than left for the next reader to discover.

- **No backups.** `restic-password` sits in `secrets.yaml` with no module consuming it. ZFS snapshots live on the same pool as the data and are not a substitute — Vaultwarden's database, the PostgreSQL databases on `r820`, and `/var/lib/*` service state are currently unprotected.
- **Alerting is a stub.** Alertmanager runs on all three servers with `smtp_from = alertmanager@example.com`, a smarthost of `localhost:25`, and a receiver with no notifier. Prometheus defines no alerting rules and no `alertmanagers` target, so nothing is evaluated and nothing would be delivered if it were.
- **Two of three Prometheus self-scrape targets are dead.** The `prometheus` job scrapes `:9090` on `r730`, `r730xd`, and `r820`, but Prometheus only runs on `r730xd`, so the other two are permanently down.
- **Duplicate node-exporter firewall rules.** Both `node-exporter.nix` and `reverse-proxy-backends.nix` add an accept rule for port 9100 from `192.168.1.2`.
- **`tests/` isn't wired into `nix flake check`.** The flake exposes no `checks` output, and `tests/default.nix` takes `pkgs ? import <nixpkgs> {}`, so the VM tests only run via `nix-build` with a channel present — CI never executes them.
- **Sanoid only covers `mediapool`.** `r730pool` gets scrubs but no snapshots, even though `fleet.r730.zpool` is defined.
- **The NAS mount can block boot.** `/mnt/share` is a plain CIFS `fileSystems` entry with no `nofail`/`x-systemd.automount`, pointing at `192.168.2.10` — a different subnet from the rest of the fleet. If the NAS is unreachable, boot waits on it.
- **The proxy is the trust boundary, and it isn't in this repo.** Every backend speaks plain HTTP and relies entirely on the `192.168.1.1`-only rule; the HAProxy config and certificates are unversioned, so half the ingress path can't be rebuilt from this flake.
- **`ytdl-sub` ships a placeholder subscription** (`igotno_username`), so the 30-minute timer runs against nothing useful until it's replaced.
- **Ports 80/443 are open on every server** via `server-core`, even though HAProxy terminates on the gateway and no host serves them.
- **`subnets.management` is `127.0.0.0/8`** — a loopback range under a name that reads like a real management network.
- **Partial `follows`.** `nixos-hardware`, `nix-cachyos-kernel`, `nix-flatpak`, and `millennium` don't follow the root `nixpkgs`, so the lock file carries several extra nixpkgs copies.
- **NUR is applied to every host** in `mkHost`, including the rack, though only `gaming.nix` consumes it.
- **Fan control** (`dell-poweredge.nix`) hands control back to the iDRAC via `ExecStop`, which only fires on a clean stop — a hard crash leaves the fans pinned at the last manual value. Its failsafe also assumes 45 °C (18–22% fans) when `lm_sensors` returns nothing.

## License

[GNU General Public License v2](LICENSE.md).
