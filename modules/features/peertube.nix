{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.peertube;
in
{
  options.modules.features.peertube.enable = lib.mkEnableOption "PeerTube video platform";

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

      localDomain = "peertube.${config.networking.myDomain}";

      listenHttp = 9000;
      listenWeb = 443;
      enableWebHttps = true;

      secrets.secretsFile = config.sops.secrets."peertube-secrets".path;

      redis = {
        enableUnixSocket = false;
        host = "127.0.0.1";
        port = 6379;
      };

      database = {
        host = config.networking.fleet.r820.ip;
        port = 5432;
        name = "peertube";
        user = "peertube";
        passwordFile = config.sops.secrets."peertube-db-password".path;
      };

      settings = {
        listen = {
          hostname = config.networking.servicesBindAddress;
          port = 9000;
        };

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

      environment = {
        # PeerTube plugin installation can invoke optional dependency
        # lifecycle scripts. Blocking them prevents an untrusted or failing
        # postinstall script from aborting plugin installation.
        npm_config_ignore_scripts = "true";
      };

      # pnpm and Node are required for plugin management; bash and coreutils
      # ensure plugin lifecycle helpers can locate standard commands even when
      # dependency scripts are ignored.
      path = with pkgs; [
        pnpm
        nodejs
        openssl
        bash
        coreutils
      ];
    };

    environment.systemPackages = with pkgs; [
      peertube
      ffmpeg
    ];
  };
}
