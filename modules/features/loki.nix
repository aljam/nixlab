{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.nixlab.loki = {
    enable = lib.mkEnableOption "Loki log aggregation server";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which Loki listens for Alloy and Grafana clients.";
    };
  };

  config = lib.mkIf config.services.nixlab.loki.enable {
    services.loki = {
      enable = true;

      configuration = {
        server = {
          http_listen_address = config.services.nixlab.loki.listenAddress;
          http_listen_port = 3100;
          grpc_listen_port = 9096;
        };

        auth_enabled = false;

        common = {
          replication_factor = 1;

          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };

        ingester = {
          lifecycler.address = "127.0.0.1";
          chunk_idle_period = "1h";
          chunk_retain_period = "30s";
          wal.enabled = true;
        };

        compactor = {
          working_directory = "/var/lib/loki/compactor";
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        storage_config = {
          filesystem.directory = "/var/lib/loki/chunks";

          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
          };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
      };
    };

    systemd.services.loki.serviceConfig = {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/loki" ];
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };

    networking.firewall.extraInputRules =
      lib.mkIf (config.services.nixlab.loki.listenAddress != "127.0.0.1")
        ''
          ip saddr ${config.networking.subnets.lan}.0/24 tcp dport 3100 accept comment "Loki from LAN"
        '';
  };
}
