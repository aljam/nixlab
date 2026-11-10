# Module catalogue

NixLab modules are reusable NixOS configurations. Hosts compose them through roles and extra modules.

## Module types

- Roles: host archetypes and baseline services.
- Features: optional, composable capabilities.
- Hardware: host- or vendor-specific configuration.

## Feature areas

- Desktop: audio, bluetooth, desktop-portals, emulation, flatpak, fonts, gaming, graphics, hyprland.
- Infrastructure: deploy-user, networking-options, networking-tools, nix-builder, nix-cache, security-policy, ssh, systemd-hardening.
- Observability: drift-monitoring, log-agent, loki, node-exporter, prometheus-alerts, prometheus-server.
- Storage: media-storage, nas-mount, restic-backup, sanoid, zfs-base.
- Media and applications: autobrr, homepage, matrix-rtc, matrix-synapse, peertube, radio, recyclarr, servarr, vaultwarden, youtube.
- Web and static content: static-site, radio-visualizer.
- Hardware: nvidia-headless, pfsense-root-ca.

## Adding a feature

Create a focused module under modules/features, use fleet networking and SOPS where applicable, add or update tests, enable it in a host or role, then run nix flake check.
