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

    sops.secrets."peertube-db-password" = {
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
        host = "192.168.1.4";
        port = 5432;
        name = "peertube";
        user = "peertube";
        passwordFile =
          config.sops.secrets."peertube-db-password".path;
      };

      settings = {
        database.ssl = true;

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

    systemd.services.peertube = {
      after = [ "redis-peertube.service" ];
      wants = [ "redis-peertube.service" ];
    };

    environment.systemPackages = with pkgs; [
      peertube
      ffmpeg
    ];
  };
}
