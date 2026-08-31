{ config, lib, ... }:
let
  bind = config.networking.servicesBindAddress;
  apps = {
    radarr         = 7878;
    sonarr         = 8989;
    lidarr         = 8686;
    bazarr         = 6767;
    prowlarr       = 9696;
    seerr          = 5055;
    shoko          = 8111;
    audiobookshelf = 13378;
    jellyfin       = 8096;
    qbittorrent    = 8080;
  };
in {
  networking.proxyBackendPorts = lib.attrValues apps;

  services = lib.mapAttrs (name: port:
    { enable = true; openFirewall = false; }
    # only some modules expose host/port options — set them where they exist
    // lib.optionalAttrs (builtins.hasAttr "port" config.services.${name} or {}) { inherit port; }
  ) apps;

  users.users = lib.genAttrs (lib.attrNames apps) (_: { extraGroups = [ "media" ]; });
}
