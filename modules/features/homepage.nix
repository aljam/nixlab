{
  config,
  lib,
  mkLink,
  ...
}:
let
  cfg = config.modules.features.homepage;
in
{
  options.modules.features.homepage.enable = lib.mkEnableOption "Homepage dashboard";

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;

      settings = {
        title = "Derezzed";
        theme = "dark";
        color = "slate";
        headerStyle = "clean";
        layout = {
          "Media & Requests" = {
            style = "row";
            columns = 3;
          };

          "Downloads" = {
            style = "row";
            columns = 4;
          };

          "Identity / communication" = {
            style = "row";
            columns = 3;
          };

          "Monitoring" = {
            style = "row";
            columns = 3;
          };
        };
      };

      services = {
        "Media & Requests" = [
          (mkLink "Jellyfin" "jellyfin" "Media Streaming" "jellyfin.png")
          (mkLink "Seerr" "seerr" "Media Requests" "seerr.png")
          (mkLink "PeerTube" "peertube" "Self-hosted Video" "peertube.png")
        ];

        "Downloads" = [
          (mkLink "Sonarr" "sonarr" "TV Automation" "sonarr.png")
          (mkLink "Radarr" "radarr" "Movie Automation" "radarr.png")
          (mkLink "Prowlarr" "prowlarr" "Indexer Management" "prowlarr.png")
          (mkLink "Bazarr" "bazarr" "Subtitles" "bazarr.png")
          (mkLink "Lidarr" "lidarr" "Music Automation" "lidarr.png")
          (mkLink "qBittorrent" "qbittorrent" "Torrent Client" "qbittorrent.png")
          (mkLink "Autobrr" "autobrr" "Release Automation" "autobrr.png")
          (mkLink "Recyclarr" "recyclarr" "Sonarr/Radarr Quality Profiles" "recyclarr.png")
        ];

        "Identity / communication" = [
          (mkLink "Vaultwarden" "vaultwarden" "Password Manager" "vaultwarden.png")
          (mkLink "Matrix" "matrix" "Chat" "matrix.png")
          (mkLink "Matrix RTC" "matrix-rtc" "Voice & Video" "matrix.png")
        ];

        "Monitoring" = [
          (mkLink "Grafana" "grafana" "Dashboards" "grafana.png")
          (mkLink "Prometheus" "prometheus" "Metrics" "prometheus.png")
          (mkLink "Alertmanager" "alertmanager" "Alerts" "alertmanager.png")
        ];
      };
    };
  };
}
