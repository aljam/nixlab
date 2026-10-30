{ config, lib, ... }:
{
  networking.proxyBackendPorts = [ 8008 ];

  sops.secrets = {
    matrix-synapse-registration-shared-secret = {
      owner = "matrix-synapse";
    };
    matrix-synapse-db-config = {
      owner = "matrix-synapse";
    };
  };

  services.matrix-synapse = {
    enable = true;

    extraConfigFiles = [
      config.sops.secrets.matrix-synapse-db-config.path
    ];

    settings = {
      server_name = "matrix.derezzed.info";
      public_baseurl = "https://matrix.derezzed.info";

      database = {
        name = "psycopg2";
        args = {
          database = "matrix-synapse";
          user = "matrix-synapse";
          host = "192.168.1.4";
          cp_min = 5;
          cp_max = 10;
        };
      };

      listeners = [
        {
          port = 8008;
          bind_addresses = [ config.networking.servicesBindAddress ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [ "client" "federation" ];
              compress = false;
            }
          ];
        }
      ];

      enable_registration = true;
      registration_requires_token = true;
      registration_shared_secret_path =
        config.sops.secrets.matrix-synapse-registration-shared-secret.path;

      experimental_features = {
        msc4140_enabled = true;
        msc4143_enabled = true;
      };

      max_event_delay_duration = "24h";

      matrix_rtc.transports = [
        {
          type = "livekit";
          url = "wss://rtc.derezzed.info/livekit/sfu";
          livekit_service_url = "https://rtc.derezzed.info/livekit/jwt";
        }
      ];
    };
  };
}
