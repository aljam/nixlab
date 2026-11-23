{ config, pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-validation-layers
    ];
  };

  # Explicitly force SDDM as the display manager and disable any conflicting defaults
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  environment.sessionVariables = {
    QT_IM_MODULE = "";
    XMODIFIERS = "";
    NIXOS_OZONE_WL = "1";
  };

  # Prefer KDE's native portal in Plasma sessions, retaining GTK as a fallback.
  xdg.portal.config.kde.default = [
    "kde"
    "gtk"
  ];

  # Add KDE Plasma so SDDM detects the desktop session files
  services.desktopManager.plasma6.enable = true;

  #services.xserver.enable = true;
}
