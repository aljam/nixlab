{ config, lib, ... }:
{
  networking.proxyBackendPorts = [ 8008 ];

  sops.secrets.matrix-synapse-registration-shared-secret = { };

  services.postgresql = {
    ensureDatabases = [ "matrix-synapse" ];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };

  services.matrix-synapse = {
    enable = true;

    settings = {
      server_name = "matrix.derezzed.info";
      public_baseurl = "https://matrix.derezzed.info";

      database = {
        name = "psycopg2";
        args = {
          database = "matrix-synapse";
          user = "matrix-synapse";
          host = "127.0.0.1";
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

      enable_registration = false;
      registration_shared_secret_path =
        config.sops.secrets.matrix-synapse-registration-shared-secret.path;

      experimental_features = {
        msc3861.enabled = false;
        msc4143_enabled = true;
      };

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
