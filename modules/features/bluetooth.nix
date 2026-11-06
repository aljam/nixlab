{ config, pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Optional: if you want a graphical Bluetooth management tray applet on KDE/Plasma/Gnome
  services.blueman.enable = true;
}
