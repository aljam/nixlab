{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.peertube;
in
{
  options.modules.features.peertube.enable =
    lib.mkEnableOption "PeerTube video platform";

  config = lib.mkIf cfg.enable {
    networking.proxyBackendPorts = [ 9000 ];

    services.peertube = {
      enable = true;

      localDomain = "peertube.derezzed.info";
      listenAddress = config.networking.fleet.r730xd.ip;
      listenPort = 9000;

      database = {
        host = "/run/postgresql";
        name = "peertube";
        user = "peertube";
      };

      settings = {
        instance.name = "Derezzed PeerTube";
        instance.short_description = "Self-hosted video";
        storage.videos = "/var/lib/peertube/storage/videos";
        storage.streaming_playlists = "/var/lib/peertube/storage/streaming-playlists";
        webserver.https = true;
        signup.enabled = false;
      };
    };

    services.postgresql = {
      ensureDatabases = [ "peertube" ];
      ensureUsers = [
        {
          name = "peertube";
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.services.peertube = {
      after = [ "postgresql.service" ];
      wants = [ "postgresql.service" ];
    };

    environment.systemPackages = with pkgs; [
      peertube
      ffmpeg
    ];
  };
}
