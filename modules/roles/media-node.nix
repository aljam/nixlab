{ config, pkgs, ... }: 

{
  imports = [
    ../features/homepage.nix
    ../features/radarr.nix
    ../features/sonarr.nix
    ../features/lidarr.nix
    ../features/bazarr.nix
    ../features/seerr.nix
    ../features/audiobookshelf.nix
    ../features/autobrr.nix
    ../features/shoko.nix
    ../features/torrents.nix
    ../features/jellyfin.nix
    ../features/recyclarr.nix
    ../features/prowlarr.nix
    ../features/vaultwarden.nix
    ../features/grafana.nix
    ../features/youtube.nix
    #../features/nas-mount.nix
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

  # Common media directories
  systemd.tmpfiles.rules = [
    "d /var/lib/media 0755 media media -"
    "d /var/lib/radarr 0755 media media -"
    "d /var/lib/sonarr 0755 media media -"
    "d /var/lib/lidarr 0755 media media -"
    "d /var/lib/readarr 0755 media media -"
    "d /var/lib/bazarr 0755 media media -"
    "d /var/lib/seerr 0755 media media -"
    "d /var/lib/audiobookshelf 0755 media media -"
    "d /var/lib/autobrr 0755 media media -"
    "d /var/lib/shoko 0755 media media -"
    "d /var/lib/jellyfin 0755 media media -"
    "d /var/lib/torrents 0755 media media -"
    "d /var/lib/vaultwarden 0755 media media -"
    "d /var/lib/grafana 0755 media media -"
  ];
}
