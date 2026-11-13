{ config, lib, ... }:
let
  matrixDomain = "matrix.${config.networking.myDomain}";
  rtcDomain = "rtc.${config.networking.myDomain}";

  cfg = config.services.matrix-synapse;

  synapseListener = lib.findFirst (listener: listener.port or 0 == 8008) { } cfg.settings.listeners;
  synapseBindAddresses = synapseListener.bind_addresses or [ ];

  registrationEnabled = cfg.settings.enable_registration or false;
  registrationCaptchaEnabled = cfg.settings.enable_registration_captcha or false;
  databaseSslMode = cfg.settings.database.args.sslmode or "";
in
{
  imports = [ ./pfsense-root-ca.nix ];

  networking.proxyBackendPorts = [ 8008 ];

  sops.secrets = {
    matrix-synapse-registration-shared-secret = {
      sopsFile = ../../secrets/matrix.yaml;
      owner = "matrix-synapse";
      group = "matrix-synapse";
      mode = "0400";
      restartUnits = [ "matrix-synapse.service" ];
    };

    matrix-synapse-db-config = {
      sopsFile = ../../secrets/matrix.yaml;
      owner = "matrix-synapse";
      group = "matrix-synapse";
      mode = "0400";
      restartUnits = [ "matrix-synapse.service" ];
    };

    matrix-recaptcha-site-key = {
      sopsFile = ../../secrets/matrix.yaml;
      owner = "matrix-synapse";
      group = "matrix-synapse";
      mode = "0400";
      restartUnits = [ "matrix-synapse.service" ];
    };

    matrix-recaptcha-secret-key = {
      sopsFile = ../../secrets/matrix.yaml;
      owner = "matrix-synapse";
      group = "matrix-synapse";
      mode = "0400";
      restartUnits = [ "matrix-synapse.service" ];
    };
  };

  services.matrix-synapse = {
    enable = true;

    extraConfigFiles = [
      config.sops.secrets.matrix-synapse-db-config.path
    ];

    settings = {
      server_name = matrixDomain;
      public_baseurl = "https://${matrixDomain}";

      media_store_path = "/var/lib/matrix-synapse/media_store";

      serve_client_wellknown = true;

      extra_well_known_client_content = {
        "org.matrix.msc4143.rtc_foci" = [
          {
            type = "livekit";
            livekit_service_url = "https://${rtcDomain}/livekit/jwt";
          }
        ];
      };

      database = {
        name = "psycopg2";
        args = {
          database = "matrix-synapse";
          user = "matrix-synapse";
          host = config.networking.fleet.r820.ip;
          sslmode = "verify-full";
          sslrootcert = config.sops.secrets.pfsense-root-ca-matrix.path;
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
              names = [
                "client"
                "federation"
              ];
              compress = false;
            }
          ];
        }
      ];

      # Public registration is intentional. CAPTCHA and a conservative
      # registration rate limit reduce automated account creation without
      # requiring invitation tokens.
      enable_registration = true;
      registration_requires_token = false;
      enable_registration_captcha = true;
      recaptcha_public_key_path = config.sops.secrets.matrix-recaptcha-site-key.path;
      recaptcha_private_key_path = config.sops.secrets.matrix-recaptcha-secret-key.path;
      registration_shared_secret_path =
        config.sops.secrets.matrix-synapse-registration-shared-secret.path;

      rc_registration = {
        per_second = 0.1;
        burst_count = 5;
      };

      experimental_features = {
        msc4140_enabled = true;
        msc4143_enabled = true;
      };

      max_event_delay_duration = "24h";

      matrix_rtc.transports = [
        {
          type = "livekit";
          url = "wss://${rtcDomain}/livekit/sfu";
          livekit_service_url = "https://${rtcDomain}/livekit/jwt";
        }
      ];
    };
  };

  systemd.services.matrix-synapse.serviceConfig = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ReadWritePaths = [ "/var/lib/matrix-synapse" ];
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

  config.assertions = [
    {
      assertion = !registrationEnabled || registrationCaptchaEnabled;
      message = "Matrix Synapse public registration must require CAPTCHA.";
    }

    {
      assertion = synapseBindAddresses != [ ] && !(lib.elem "0.0.0.0" synapseBindAddresses) && !(lib.elem "::" synapseBindAddresses);
      message = "Matrix Synapse must not bind its HTTP listener to every interface.";
    }

    {
      assertion = databaseSslMode == "verify-full";
      message = "Matrix Synapse must verify the PostgreSQL server certificate with sslmode=verify-full.";
    }
  ];
}
