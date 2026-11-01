{ config, lib, pkgs, ... }:

{
  networking.proxyBackendPorts = [
    9090
    9115
  ];

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = config.networking.servicesBindAddress;

    ruleFiles = [ ./prometheus-rules.yml ];

    alertmanagers = [
      {
        static_configs = [
          {
            targets = [ "127.0.0.1:9093" ];
          }
        ];
      }
    ];

    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    scrapeConfigs = [
      {
        job_name = "prometheus";

        static_configs = [
          {
            targets = [
              "${config.networking.fleet.r730xd.ip}:9090"
            ];
          }
        ];
      }

      {
        job_name = "node";

        static_configs = [
          {
            targets = [ "${config.networking.fleet.r730.ip}:9100" ];
            labels = {
              instance = "r730";
              host = "r730";
            };
          }

          {
            targets = [ "${config.networking.fleet.r730xd.ip}:9100" ];
            labels = {
              instance = "r730xd";
              host = "r730xd";
            };
          }

          {
            targets = [ "${config.networking.fleet.r820.ip}:9100" ];
            labels = {
              instance = "r820";
              host = "r820";
            };
          }
        ];
      }

      {
        job_name = "blackbox-postgres";
        metrics_path = "/probe";
        params = {
          module = [ "tcp_postgres" ];
        };

        static_configs = [
          {
            targets = [ "${config.networking.fleet.r820.ip}:5432" ];
            labels = {
              instance = "r820-postgresql";
              host = "r820";
            };
          }
        ];

        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }

      {
        job_name = "blackbox-postgres-tls";
        metrics_path = "/probe";
        params = {
          module = [ "tls_postgres" ];
        };

        static_configs = [
          {
            targets = [ "${config.networking.fleet.r820.ip}:5432" ];
            labels = {
              instance = "r820-postgresql-tls";
              host = "r820";
            };
          }
        ];

        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9115";
          }
        ];
      }
    ];

    exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9115;

      configFile = pkgs.writeText "blackbox.yml" (
        builtins.toJSON {
          modules = {
            tcp_postgres = {
              prober = "tcp";
              timeout = "5s";
              tcp = {
                preferred_ip_protocol = "ip4";
              };
            };

            tls_postgres = {
              prober = "tcp";
              timeout = "5s";
              tcp = {
                preferred_ip_protocol = "ip4";
                tls = true;
                tls_config = {
                  insecure_skip_verify = true;
                };
              };
            };
          };
        }
      );
    };
  };
}
