# Consolidated media automation stack ("*arr" and friends).
#
# Security: none of these services are exposed to the LAN. They listen on the
# host's fleet address and are reachable only through the HAProxy gateway;
# the per-backend firewall rules are generated centrally from
# `networking.proxyBackendPorts` in reverse-proxy-backends.nix.
#
# The `ports` attrset below is the single source of truth for the web UI port
# of every service in the stack. Service options are declared explicitly rather
# than generated, because the upstream modules do not share a common option
# surface (some take `port`, some `webuiPort`, some neither).
{ config, lib, ... }:
let
  ports = {
    radarr = 7878;
    sonarr = 8989;
    lidarr = 8686;
    bazarr = 6767;
    prowlarr = 9696;
    seerr = 5055;
    shoko = 8111;
    audiobookshelf = 13378;
    jellyfin = 8096;
    qbittorrent = 8080;
  };

  # Services whose upstream module creates a static system user; those users can
  # be added to the shared `media` group by name.
  staticUserServices = [
    "radarr"
    "sonarr"
    "lidarr"
    "bazarr"
    "audiobookshelf"
    "jellyfin"
    "qbittorrent"
  ];

  # Services whose upstream module runs with `DynamicUser = true`. They have no
  # persistent user account, so group membership has to be granted on the unit
  # via SupplementaryGroups instead of `users.users.<name>.extraGroups`.
  dynamicUserServices = [
    "prowlarr"
    "seerr"
    "shoko"
  ];
in
{
  networking.proxyBackendPorts = lib.attrValues ports;

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
      port = ports.audiobookshelf;
    };

    jellyfin = {
      enable = true;
      group = "media";
    };

    qbittorrent = {
      enable = true;
      webuiPort = ports.qbittorrent;
    };
  };

  # Inbound BitTorrent swarm port. This is the only port in the stack that is
  # deliberately reachable from outside the gateway; without it qBittorrent can
  # only make outbound connections.
  networking.firewall.allowedTCPPorts = [ 6881 ];
  networking.firewall.allowedUDPPorts = [ 6881 ];

  # Shared access to /mnt/media. Declaring membership on the group (rather than
  # `users.users.<name>.extraGroups`) means this module never has to define a
  # user that an upstream service module owns.
  users.groups.media.members = staticUserServices;

  systemd.services = lib.genAttrs (lib.attrNames ports) (name: {
    serviceConfig =
      {
        # /mnt/media is setgid `media`; a group-writable umask is what makes the
        # shared-ownership scheme actually work for newly written files.
        UMask = lib.mkForce "0002";
      }
      // lib.optionalAttrs (lib.elem name dynamicUserServices) {
        SupplementaryGroups = [ "media" ];
      };
  });
}
