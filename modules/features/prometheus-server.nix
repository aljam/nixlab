{ config, lib, pkgs, ... }:

let
  cfg = config.modules.features.prometheus-server;
  primaryDomain = config.networking.domains.primary;
  matrixUrl = "https://matrix.${primaryDomain}";
  rtcUrl = "https://rtc.${primaryDomain}";
in
{
  options.modules.features.prometheus-server = {
    postgresCaFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a CA bundle used to verify PostgreSQL TLS certificates.
        When null, the TLS PostgreSQL Blackbox probe is omitted.
      '';
    };
  };

  config = {
    # Prometheus, Alertmanager, and the Blackbox exporter are internal-only.
    # Grafana is the internet-facing monitoring surface.
    assertions = [
      {
        assertion = !(lib.elem 9090 config.networking.proxyBackendPorts);
        message = "Prometheus must not be exposed through the HAProxy backend allowlist.";
      }
      {
        assertion = !(lib.elem 9115 config.networking.proxyBackendPorts);
        message = "The Prometheus Blackbox exporter must not be exposed through the HAProxy backend allowlist.";
      }
      {
        assertion = !(lib.elem 9093 config.networking.proxyBackendPorts);
        message = "Alertmanager must not be exposed through the HAProxy backend allowlist.";
      }
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
          job_name = "blackbox-matrix-client";
          metrics_path = "/probe";
          params = {
            module = [ "http_2xx" ];
          };

          static_configs = [
            {
              targets = [ "${matrixUrl}/_matrix/client/versions" ];
              labels = {
                instance = "matrix-client";
                host = "r730xd";
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
          job_name = "blackbox-matrix-federation";
          metrics_path = "/probe";
          params = {
            module = [ "http_2xx" ];
          };

          static_configs = [
            {
              targets = [ "${matrixUrl}/_matrix/key/v2/server" ];
              labels = {
                instance = "matrix-federation";
                host = "r730xd";
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
          job_name = "blackbox-matrix-rtc";
          metrics_path = "/probe";
          params = {
            module = [ "http_2xx" ];
          };

          static_configs = [
            {
              targets = [ rtcUrl ];
              labels = {
                instance = "matrix-rtc";
                host = "r730xd";
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
      ] ++ lib.optionals (cfg.postgresCaFile != null) [
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
              http_2xx = {
                prober = "http";
                timeout = "10s";
                http = {
                  preferred_ip_protocol = "ip4";
                  valid_status_codes = [ 200 ];
                };
              };
              tcp_postgres = {
                prober = "tcp";
                timeout = "5s";
                tcp = {
                  preferred_ip_protocol = "ip4";
                };
              };
            } // lib.optionalAttrs (cfg.postgresCaFile != null) {
              tls_postgres = {
                prober = "tcp";
                timeout = "5s";
                tcp = {
                  preferred_ip_protocol = "ip4";
                  tls = true;
                  tls_config = {
                    ca_file = cfg.postgresCaFile;
                  };
                };
              };
            };
          }
        );
      };
    };
  };
}
