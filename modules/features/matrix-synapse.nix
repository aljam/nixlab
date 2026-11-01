{ config, lib, ... }:
{
  networking.proxyBackendPorts = [ 8008 ];

  sops.secrets = {
    matrix-synapse-registration-shared-secret = {
      sopsFile = ../../secrets/matrix.yaml;
      owner = "matrix-synapse";
    };

    matrix-synapse-db-config = {
      sopsFile = ../../secrets/matrix.yaml;
      owner = "matrix-synapse";
    };

    pfsense-root-ca = {
      sopsFile = ../../secrets/matrix.yaml;
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

      serve_client_wellknown = true;

      extra_well_known_client_content = {
        "org.matrix.msc4143.rtc_foci" = [
          {
            type = "livekit";
            livekit_service_url = "https://rtc.derezzed.info/livekit/jwt";
          }
        ];
      };

      database = {
        name = "psycopg2";
        args = {
          database = "matrix-synapse";
          user = "matrix-synapse";
          host = "r820.derezzed.info";
          sslmode = "verify-full";
          sslrootcert = config.sops.secrets.pfsense-root-ca.path;
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
