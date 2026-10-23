# Consolidated media automation stack ("*arr" and friends).
#
# Security: none of these services are exposed to the LAN. They listen on the
# host's fleet address and are reachable only through the HAProxy gateway;
# the per-backend firewall rules are generated centrally from
# `networking.proxyBackendPorts` in reverse-proxy-backends.nix.
#
# `serviceDefs` is the single source of truth for each service's web UI port
# and shared-group model. Upstream service options remain explicit because the
# upstream modules do not share a common option surface.
{
  config,
  lib,
  ...
}:
let
  cfg = config.nixlab.servarr;

  serviceDefs = {
    radarr = {
      port = 7878;
      userType = "static";
    };

    sonarr = {
      port = 8989;
      userType = "static";
    };

    lidarr = {
      port = 8686;
      userType = "static";
    };

    bazarr = {
      port = 6767;
      userType = "static";
    };

    prowlarr = {
      port = 9696;
      userType = "dynamic";
    };

    seerr = {
      port = 5055;
      userType = "dynamic";
    };

    shoko = {
      port = 8111;
      userType = "dynamic";
    };

    audiobookshelf = {
      port = 13378;
      userType = "static";
    };

    jellyfin = {
      port = 8096;
      userType = "static";
    };

    qbittorrent = {
      port = 8080;
      userType = "static";
    };
  };

  staticServices = lib.filterAttrs (
    _: service: service.userType == "static"
  ) serviceDefs;

  dynamicServices = lib.filterAttrs (
    _: service: service.userType == "dynamic"
  ) serviceDefs;
in
{
  options.nixlab.servarr.enable = lib.mkEnableOption "media automation stack";

  config = lib.mkIf cfg.enable {
    networking.proxyBackendPorts = lib.mapAttrsToList (
      _: service: service.port
    ) serviceDefs;

    services = {
      radarr.enable = true;
      sonarr.enable = true;
      lidarr.enable = true;
      prowlarr.enable = true;

      bazarr = {
        enable = true;
        openFirewall = false;
      };

      seerr = {
        enable = true;
        openFirewall = false;
      };

      shoko = {
        enable = true;
        openFirewall = false;
      };

      audiobookshelf = {
        enable = true;
        host = config.networking.servicesBindAddress;
        port = serviceDefs.audiobookshelf.port;
      };

      jellyfin = {
        enable = true;
        group = "media";
      };

      qbittorrent = {
        enable = true;
        webuiPort = serviceDefs.qbittorrent.port;
      };
    };

    # Inbound BitTorrent swarm port. This is the only port in the stack that is
    # deliberately reachable from outside the gateway; without it qBittorrent can
    # only make outbound connections.
    networking.firewall.allowedTCPPorts = [ 6881 ];
    networking.firewall.allowedUDPPorts = [ 6881 ];

    # Shared access to /mnt/media. Declaring membership on the group (rather
    # than `users.users.<name>.extraGroups`) means this module never has to
    # define a user that an upstream service module owns.
    users.groups.media.members = lib.attrNames staticServices;

    systemd.services = lib.genAttrs (lib.attrNames serviceDefs) (name: {
      serviceConfig =
        {
          # /mnt/media is setgid `media`; a group-writable umask is what makes
          # the shared-ownership scheme work for newly written files.
          UMask = lib.mkForce "0002";
        }
        // lib.optionalAttrs (lib.hasAttr name dynamicServices) {
          SupplementaryGroups = [ "media" ];
        };
    });
  };
}
