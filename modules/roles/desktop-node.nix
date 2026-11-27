{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/features/audio.nix
    ../../modules/features/bluetooth.nix
    ../../modules/features/graphics.nix
    ../../modules/features/hyprland.nix
    ../../modules/features/emulation.nix
    ../../modules/features/nas-mount.nix
    ../../modules/features/networking-tools.nix
    ../../modules/features/developer-tools.nix
    ../../modules/features/gaming.nix
    ../../modules/features/gaming-performance.nix
    ../../modules/features/power-profiles.nix
    ../../modules/features/libvirt.nix
    ../../modules/features/flatpak.nix
    ../../modules/features/fonts.nix
    ../../modules/features/gen1recomp.nix
    ../../modules/features/desktop-portals.nix
    ../../modules/features/reverse-proxy-backends.nix
    ../../modules/features/node-exporter.nix
    ../../modules/features/restic-backup.nix
    ../../modules/features/backup-assurance.nix
    ../../modules/features/tailscale-health.nix
    ../../modules/features/opencode-secret.nix
  ];

  boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest";

  networking.networkmanager.enable = true;

  services.scx-loader = {
    enable = true;
    config = {
      default_sched = "scx_lavd";
      default_mode = "Auto";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    extraUpFlags = [ "--accept-routes=true" ];
  };

  modules.features.tailscale-health.enable = true;

  modules.features.restic-backup.enable = true;
  modules.features.restic-backup.jobs.home-directories = {
    repository = "/var/lib/restic-backup/repo";
    paths = [ "/home" ];
  };

  programs.kdeconnect.enable = true;

  modules.features.power-profiles.enable = true;

  modules.features.opencodeSecret.enable = true;

  programs.gen1recomp = {
    enable = true;

    # Verified with:
    # nix store prefetch-file --json \
    #   'https://github.com/bryanthaboi/gen1recomp/releases/download/v0.2.57/gen1recomp.love'
    hash = "sha256-lj9oPiWmrNPvNyYb+GbEmrdfqn00jzwxQfbXVoTg+40=";
  };

  # Desktops and laptops get the local libvirt GUI.
  modules.features.libvirt.gui.enable = true;

  # Developer and API debugging tools for desktop hosts.
  modules.features.developerTools.enable = true;
}
