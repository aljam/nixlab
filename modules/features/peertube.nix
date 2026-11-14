{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.peertube;

  peertubeSettings = config.services.peertube.settings or { };
  peertubeListener = peertubeSettings.listen or { };
  peertubeHostname = peertubeListener.hostname or "";
  signupEnabled = peertubeSettings.signup.enabled or false;

  redisServer = config.services.redis.servers.peertube or { };
  redisBind = redisServer.bind or "";
in
{
  options.modules.features.peertube.enable = lib.mkEnableOption "PeerTube video platform";

  config = lib.mkIf cfg.enable {
    networking.proxyBackendPorts = [ 9000 ];

    sops.secrets."peertube-secrets" = mkSecret {
      name = "peertube-secrets";
      sopsFile = ../../secrets/peertube.yaml;
      owner = "peertube";
      group = "peertube";
      restartUnits = [ "peertube.service" ];
    };

    sops.secrets."peertube-db-password" = mkSecret {
      name = "peertube-db-password";
      sopsFile = ../../secrets/peertube.yaml;
      owner = "peertube";
      group = "peertube";
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
      bind = "127.0.0.1";
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

      serviceConfig = {
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/peertube" ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        CapabilityBoundingSet = [ ];
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
    };

    environment.systemPackages = with pkgs; [
      peertube
      ffmpeg
    ];

    assertions = [
      {
        assertion = !signupEnabled;
        message = "PeerTube registration must remain disabled.";
      }

      {
        assertion = peertubeHostname != "" && peertubeHostname != "0.0.0.0" && peertubeHostname != "::";
        message = "PeerTube must bind its HTTP listener to an explicit service address, not every interface.";
      }

      {
        assertion = redisBind == "127.0.0.1";
        message = "PeerTube Redis must listen only on loopback.";
      }
    ];
  };
}
