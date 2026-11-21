{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  programs.hyprland = {
    enable = lib.mkDefault true;
    withUWSM = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;

    package = lib.mkDefault inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      lib.mkDefault
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  services.displayManager.sddm = {
    enable = lib.mkDefault true;
    wayland.enable = lib.mkDefault true;
  };

  services.desktopManager.plasma6.enable = lib.mkDefault true;
}
