{ config, pkgs, ... }:
let
  domain = config.networking.domains.primary;

  mkLink =
    name: subdomain: description: icon:
    {
      ${name} = {
        href = "https://${subdomain}.${domain}";
        inherit description icon;
      };
    };
in
{
  networking.proxyBackendPorts = [ 8082 ];

  services.homepage-dashboard = {
    enable = true;
    # Restrict accepted Host headers to the public dashboard hostname.
    allowedHosts = "home.${domain}";

    # Only advertise services that are intentionally reachable through the
    # public reverse-proxy path. pgAdmin is loopback-only and must not be
    # listed here.
    services = [
      {
        "Media & Requests" = [
          (mkLink "Jellyfin" "jellyfin" "Media Streaming" "jellyfin.png")
          (mkLink "Seerr" "seerr" "Media Requests" "seerr.png")
          (mkLink "Audiobookshelf" "audiobookshelf" "Audiobooks & Podcasts" "audiobookshelf.png")
        ];
      }
      {
        "Automation & Downloads" = [
          (mkLink "Sonarr" "sonarr" "TV Shows" "sonarr.png")
          (mkLink "Radarr" "radarr" "Movies" "radarr.png")
          (mkLink "Prowlarr" "prowlarr" "Indexers" "prowlarr.png")
          (mkLink "Bazarr" "bazarr" "Subtitles Automation" "bazarr.png")
          (mkLink "Lidarr" "lidarr" "Music Automation" "lidarr.png")
          (mkLink "qBittorrent" "qb" "Torrents" "qbittorrent.png")
          (mkLink "Autobrr" "autobrr" "IRC Torrent Filters" "autobrr.png")
          (mkLink "Shoko" "shoko" "AniDB integration" "shoko.png")
        ];
      }
      {
        "System & Monitoring" = [
          (mkLink "Grafana" "grafana" "Metrics & Dashboards" "grafana.png")
        ];
      }
    ];
  };
}
