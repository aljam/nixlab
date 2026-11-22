{ config, pkgs, ... }:

{
  services.flatpak = {
    enable = true;
    update = {
      auto = {
        enable = true;
      };
    };
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "appcenter";
        location = "https://flatpak.elementary.io/repo";
      }
    ];
    packages = [
      {
        appId = "org.vinegarhq.Sober";
        origin = "flathub";
      }
      "com.github.PintaProject.Pinta"
      "com.fightcade.Fightcade"
    ];
  };

  # Declarative Flatpak overrides for Fightcade
  services.flatpak.overrides = {
    "com.fightcade.Fightcade" = {
      context.sockets = [
        "x11"
        "wayland"
      ];
      environment = {
        USE_DXVK = "true";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
      };
    };

    # OpenDeck fails under the system-wide X11-only override;
    # force its native Wayland socket instead.
    "me.amankhanna.opendeck" = {
      context.sockets = [
        "wayland"
      ];
    };
  };
}
