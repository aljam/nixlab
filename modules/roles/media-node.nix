{ config, pkgs, ... }: 

{
  imports = [
    ../features/homepage.nix
    #../features/radarr.nix
    #../features/sonarr.nix
    #../features/lidarr.nix
    #../features/bazarr.nix
    #../features/seerr.nix
    #../features/audiobookshelf.nix
    ../features/autobrr.nix
    #../features/shoko.nix
    #../features/torrents.nix
    #../features/jellyfin.nix
    ../features/recyclarr.nix
    #../features/prowlarr.nix
    ../features/vaultwarden.nix
    ../features/grafana.nix
    ../features/youtube.nix
    #../features/nas-mount.nix
    ../features/servarr.nix
  ];

  # Media user and group
  users.users.media = {
    description = "Media services user";
    group = "media";
    home = "/var/lib/media";
    createHome = true;
    isSystemUser = true;
  };

  users.groups.media = {};

  systemd.tmpfiles.rules = [
    "d /mnt/media        2775 media media -"   # setgid so new files inherit `media`
    "d /mnt/media/movies 2775 media media -"
    "d /mnt/media/tv     2775 media media -"
  ];

}
