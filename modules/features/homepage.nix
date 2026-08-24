{ config, pkgs, ... }:

{
  networking.proxyBackendPorts = [ 8082 ];

  services.homepage-dashboard = {
    enable = true;
    # Binds to localhost to prevent HAProxy Host header validation errors
    allowedHosts = "home.${config.networking.domains.primary}";
    
    services = [
      {
        "Media & Requests" = [
          { Jellyfin = { href = "https://jellyfin.${config.networking.domains.primary}"; description = "Media Streaming"; icon = "jellyfin.png"; }; }
          { Seerr = { href = "https://seerr.${config.networking.domains.primary}"; description = "Media Requests"; icon = "seerr.png"; }; }
          { Audiobookshelf = { href = "https://audiobookshelf.${config.networking.domains.primary}"; description = "Audiobooks & Podcasts"; icon = "audiobookshelf.png"; }; }
        ];
      }
      {
        "Automation & Downloads" = [
          { Sonarr = { href = "https://sonarr.${config.networking.domains.primary}"; description = "TV Shows"; icon = "sonarr.png"; }; }
          { Radarr = { href = "https://radarr.${config.networking.domains.primary}"; description = "Movies"; icon = "radarr.png"; }; }
          { Prowlarr = { href = "https://prowlarr.${config.networking.domains.primary}"; description = "Indexers"; icon = "prowlarr.png"; }; }
          { Bazarr = { href = "https://bazarr.${config.networking.domains.primary}"; description = "Subtitles Automation"; icon = "bazarr.png"; }; }
          { Lidarr = { href = "https://lidarr.${config.networking.domains.primary}"; description = "Music Automation"; icon = "lidarr.png"; }; }
          { qBittorrent = { href = "https://qb.${config.networking.domains.primary}"; description = "Torrents"; icon = "qbittorrent.png"; }; }
          { Autobrr = { href = "https://autobrr.${config.networking.domains.primary}"; description = "IRC Torrent Filters"; icon = "autobrr.png"; }; }
          { Shoko = { href = "https://shoko.${config.networking.domains.primary}"; description = "AniDB integration"; icon = "shoko.png"; }; }
        ];
      }
      {
        "System & Monitoring" = [
          { Grafana = { href = "https://grafana.${config.networking.domains.primary}"; description = "Metrics & Dashboards"; icon = "grafana.png"; }; }
          { Pgadmin = { href = "https://db.${config.networking.domains.primary}"; description = "Databases"; icon = "pgadmin.png"; }; }
        ];
      }
    ];
  };
}
