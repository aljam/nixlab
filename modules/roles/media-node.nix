{ config, pkgs, ... }:

{
  imports = [
    ../features/homepage.nix
    ../features/autobrr.nix
    ../features/recyclarr.nix
    ../features/vaultwarden.nix
    ../features/grafana
    #../features/youtube.nix
    ../features/servarr.nix
    ../features/matrix-synapse.nix
    ../features/matrix-rtc.nix
    ../features/static-site.nix
    ../features/radio.nix
    ../features/radio-visualizer.nix
    ../features/peertube.nix
  ];

  modules.features.homepage.enable = true;

  # Media user and group
  users.users.media = {
    description = "Media services user";
    group = "media";
    home = "/var/lib/media";
    createHome = true;
    isSystemUser = true;
  };

  servarr.enable = true;

  users.groups.media = { };

  systemd.tmpfiles.rules = [
    # setgid so new files inherit `media`
    "d /mnt/media 2775 media media -"
    "d /mnt/media/movies 2775 media media -"
    "d /mnt/media/tv 2775 media media -"
  ];
}
