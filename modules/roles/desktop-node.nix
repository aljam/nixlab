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
    ../../modules/features/gaming.nix
    ../../modules/features/libvirt.nix
    ../../modules/features/flatpak.nix
    ../../modules/features/fonts.nix
    ../../modules/features/gen1recomp.nix
    ../../modules/features/desktop-portals.nix
  ];

  boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest";

  # Binary caches for desktop-only software, in addition to the fleet-wide
  # ones in modules/features/nix-cache.nix.
  nix.settings.substituters = [
    "https://nix-gaming.cachix.org"
    "https://hyprland.cachix.org"
  ];

  nix.settings.trusted-public-keys = [
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svX0aZb1a0a3cec5fdb"
  ];

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

  programs.kdeconnect.enable = true;

  programs.gen1recomp = {
    enable = true;

    # Replace this with the hash returned by nix store prefetch-file.
    hash = "sha256-lj9oPiWmrNPvNyYb+GbEmrdfqn00jzwxQfbXVoTg+40=";
  };

  # Desktops and laptops get the local libvirt GUI.
  modules.features.libvirt.gui.enable = true;
}
