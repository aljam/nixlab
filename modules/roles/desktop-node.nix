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
    ../../modules/features/gaming.nix
    ../../modules/features/libvirt.nix
    ../../modules/features/flatpak.nix
    ../../modules/features/remote-builder.nix
    ../../modules/features/fonts.nix
    ../../modules/features/gen1recomp.nix
  ];
  
  boot.kernelPackages = inputs.nix-cachyos-kernel.legacyPackages.x86_64-linux.linuxPackages-cachyos-lts;

  networking.networkmanager.enable = true;
  
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    extraUpFlags = [
      "--accept-routes=true"
    ];
  };

  programs.kdeconnect.enable = true;

  programs.gen1recomp = {
    enable = true;

    # Replace this with the hash returned by nix store prefetch-file.
    hash = "sha256-lj9oPiWmrNPvNyYb+GbEmrdfqn00jzwxQfbXVoTg+40=";
  };
}
