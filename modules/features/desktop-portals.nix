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

  # Required for Wayland screen sharing, capture, and desktop privilege prompts.
  security.polkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    wl-clip-persist
    grim
    slurp
    zenity
  ];
}
