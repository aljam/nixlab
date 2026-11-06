{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  # Enable Hyprland window manager via NixOS module
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  # Universal Wayland environment variables (safe for AMD, Intel, and Nvidia)
  environment.sessionVariables = lib.mkMerge [
    {
      NIXOS_OZONE_WL = "1"; # Forces Electron apps to use Wayland natively
      MOZ_ENABLE_WAYLAND = "1"; # Forces Firefox to use native Wayland
    }
    # Conditionally apply Nvidia backend variables ONLY if Nvidia is enabled on that host
    (lib.mkIf (config.hardware.nvidia.enable or false) {
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    })
  ];

  # System-level packages required for Hyprland & ricing utilities
  environment.systemPackages = with pkgs; [
    waybar
    swaynotificationcenter
    fuzzel
    awww
    hyprlock
    hypridle
    wl-clipboard
    cliphist
    grim
    slurp
    brightnessctl
    pamixer
  ];
}
