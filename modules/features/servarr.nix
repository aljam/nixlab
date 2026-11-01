{ config, lib, pkgs, ... }:

let
  cfg = config.modules.features.servarr;
  domain = config.networking.domains.primary;
  hostName = config.networking.hostName;
  proxyIP = config.networking.fleet.proxy.ip;
  bindAddress = config.networking.servicesBindAddress;
  mediaGroup = config.users.groups.media.name;
in
{
  options.modules.features.servarr = {
    enable = lib.mkEnableOption "Servarr media automation stack";
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = { };
    users.users.media = {
      isSystemUser = true;
      group = "media";
      home = "/var/lib/media";
      createHome = true;
    };

    services.prowlarr.enable = true;
    services.radarr.enable = true;
    services.sonarr.enable = true;
    services.bazarr.enable = true;

    services.prowlarr.settings = {
      server = {
        bind_address = bindAddress;
        port = 9696;
      };
    };

    services.radarr.settings = {
      server = {
        bind_address = bindAddress;
        port = 7878;
      };
    };

    services.sonarr.settings = {
      server = {
        bind_address = bindAddress;
        port = 8989;
      };
    };

    services.bazarr.settings = {
      server = {
        bind_address = bindAddress;
        port = 6767;
      };
    };

    # qBittorrent uses a separate WebUI port and is intentionally not exposed
    # through HAProxy. Its BitTorrent listener uses TCP/UDP 6881 so it can
    # accept inbound peer connections; this is the only intentionally broad
    # firewall opening in this module.
    services.qbittorrent = {
      enable = true;
      openFirewall = false;
      settings = {
        server = {
          bind_address = bindAddress;
          port = 8080;
        };

        bitorrent = {
          port = 6881;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 6881 ];
    networking.firewall.allowedUDPPorts = [ 6881 ];

    networking.proxyBackendPorts = [
      9696
      7878
      8989
      6767
    ];

    environment.systemPackages = with pkgs; [
      qbittorrent
    ];
  };
}
