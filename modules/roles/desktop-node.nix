{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

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
    ../../modules/features/tailscale-health.nix
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

  # navi and oryx run tailscaled directly and consume the pfSense subnet route.
  modules.features.tailscale-health.enable = true;

  programs.kdeconnect.enable = true;

  # Opt in per desktop host after validating thermals and battery impact.
  modules.features.gaming-performance.enable = false;

  modules.features.power-profiles.enable = true;

  programs.gen1recomp = {
    enable = true;

    # Verified with:
    # nix store prefetch-file --json \
    #   'https://github.com/bryanthaboi/gen1recomp/releases/download/v0.2.57/gen1recomp-0.2.57.love'
    hash = "sha256-lj9oPiWmrNPvNyYb+GbEmrdfqn00jzwxQfbXVoTg+40=";
  };

  # Desktops and laptops get the local libvirt GUI.
  modules.features.libvirt.gui.enable = true;

  # Developer and API debugging tools for desktop hosts.
  modules.features.developerTools.enable = true;
}
