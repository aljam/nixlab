{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rules are sourced from OpenDeck's Linux device-access rules.
  # They grant the active desktop session access to Elgato Stream Deck
  # USB and hidraw devices using Elgato's vendor ID 0fd9.
  streamdeck-udev-rules = pkgs.writeTextDir "etc/udev/rules.d/40-streamdeck.rules" ''
    # Elgato Stream Deck devices
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
  '';
in
{
  options.features.streamdeck.enable = lib.mkEnableOption "Stream Deck support with OpenDeck";

  config = lib.mkIf config.features.streamdeck.enable {
    services.flatpak.packages = [
      {
        appId = "me.amankhanna.opendeck";
        origin = "flathub";
      }
    ];

    services.udev.packages = [
      streamdeck-udev-rules
    ];
  };
}
