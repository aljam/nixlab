{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.peertube;
in
{
  options.modules.features.peertube.enable =
    lib.mkEnableOption "PeerTube video platform";

  config = lib.mkIf cfg.enable {
    networking.proxyBackendPorts = [ 9000 ];

    sops.secrets."peertube-secrets" = {
      sopsFile = ../../secrets/peertube.yaml;
      owner = "peertube";
      group = "peertube";
      mode = "0400";
      restartUnits = [ "peertube.service" ];
    };

    services.peertube = {
      enable = true;

      localDomain = "peertube.derezzed.info";

      listenHttp = 9000;
      listenWeb = 443;
      enableWebHttps = true;

      secrets.secretsFile =
        config.sops.secrets."peertube-secrets".path;

      redis = {
        enableUnixSocket = false;
        host = "127.0.0.1";
        port = 6379;
      };

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
        signup.enabled = false;
      };
    };

    services.redis.servers.peertube = {
      enable = true;
      port = 6379;
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
      after = [
        "postgresql.service"
        "redis-peertube.service"
      ];
      wants = [
        "postgresql.service"
        "redis-peertube.service"
      ];
    };

    environment.systemPackages = with pkgs; [
      peertube
      ffmpeg
    ];
  };
}
