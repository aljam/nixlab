{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.features.homepage;

  mkLink = name: service: description: icon: {
    ${name} = {
      inherit description icon;
      href = "https://${service}.derezzed.info";
    };
  };
in
{
  options.modules.features.homepage.enable = lib.mkEnableOption "Homepage dashboard";

  config = lib.mkIf cfg.enable {
    # Allow the pfSense HAProxy gateway to reach the dashboard backend.
    networking.proxyBackendPorts = [ 8082 ];

    services.homepage-dashboard = {
      enable = true;

      # Homepage rejects requests with an unlisted Host header. Allow the
      # public HAProxy hostname and the direct LAN backend address.
      allowedHosts = "home.derezzed.info,192.168.1.2:8082";

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

      # The NixOS Homepage module expects a list of service groups. Each
      # service must be keyed by its display name.
      services = [
        {
          "Media & Requests" = [
            (mkLink "Jellyfin" "jellyfin" "Media Streaming" "jellyfin.png")
            (mkLink "Seerr" "seerr" "Media Requests" "seerr.png")
            (mkLink "PeerTube" "peertube" "Self-hosted Video" "peertube.png")
          ];
        }

        {
          "Downloads" = [
            (mkLink "Sonarr" "sonarr" "TV Automation" "sonarr.png")
            (mkLink "Radarr" "radarr" "Movie Automation" "radarr.png")
            (mkLink "Prowlarr" "prowlarr" "Indexer Management" "prowlarr.png")
            (mkLink "Bazarr" "bazarr" "Bazarr Subtitles" "bazarr.png")
            (mkLink "Lidarr" "lidarr" "Music Automation" "lidarr.png")
            (mkLink "qBittorrent" "qbittorrent" "Torrent Client" "qbittorrent.png")
            (mkLink "Autobrr" "autobrr" "Release Automation" "autobrr.png")
            (mkLink "Recyclarr" "recyclarr" "Sonarr/Radarr Quality Profiles" "recyclarr.png")
          ];
        }

        {
          "Identity / communication" = [
            (mkLink "Vaultwarden" "vault" "Password Manager" "vaultwarden.png")
            (mkLink "Matrix" "matrix" "Chat" "matrix.png")
            (mkLink "Matrix RTC" "matrix-rtc" "Voice & Video" "matrix.png")
          ];
        }

        {
          "Monitoring" = [
            (mkLink "Grafana" "grafana" "Dashboards" "grafana.png")
          ];
        }
      ];
    };
  };
}
