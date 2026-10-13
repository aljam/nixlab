{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Provides D-Bus, the XDG Desktop Portal service, and the GTK portal
  # backend used by applications such as WordCraft for native file dialogs.
  services.dbus.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "gtk" ];
  };

  # Fallback used by rfd when the portal backend is unavailable.
  environment.systemPackages = [ pkgs.zenity ];
}
