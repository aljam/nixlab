{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.prometheus-server;
  primaryDomain = config.networking.domains.primary;
  matrixUrl = "https://matrix.${primaryDomain}";
  rtcUrl = "https://rtc.${primaryDomain}";
  physicalHosts = [
    "r730"
    "r730xd"
    "r820"
  ];

  # Every Blackbox probe sends the original target to the loopback exporter
  # and preserves it as the Prometheus instance label.
  blackboxRelabelConfigs = [
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

  # Shared with .github/workflows/edge-security.yml; see docs/PUBLIC_SERVICES.md.
  publicEndpoints =
    (builtins.fromJSON (builtins.readFile ../../docs/public-endpoints.json)).endpoints;

  publicBlackboxScrapeJobs = [
    {
      job_name = "blackbox-public";
      metrics_path = "/probe";
      params = {
        module = [ "http_2xx" ];
      };

      static_configs = map (endpoint: {
        targets = [ endpoint.url ];
        labels = {
          instance = endpoint.name;
          endpoint = endpoint.name;
        };
      }) publicEndpoints;

      relabel_configs = blackboxRelabelConfigs;
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

      relabel_configs = blackboxRelabelConfigs;
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

      relabel_configs = blackboxRelabelConfigs;
    }

    {
      job_name = "blackbox-matrix-rtc";
      metrics_path = "/probe";
      params = {
        module = [ "http_2xx" ];
      };

      static_configs = [
        {
          targets = [ "${rtcUrl}" ];
          labels = {
            instance = "matrix-rtc";
            host = "r730xd";
          };
        }
      ];

      relabel_configs = blackboxRelabelConfigs;
    }
  ];
in
{
  options.modules.features.prometheus-server = {
    postgresCaFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a CA bundle used to verify PostgreSQL TLS certificates. When null, the TLS PostgreSQL Blackbox probe is omitted.";
    };

    enablePublicEndpointProbes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure Blackbox probes for public HTTPS endpoints. Disable in isolated NixOS VM tests, which have no DNS or Internet access.";
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

      ruleFiles = [ ./prometheus/rules/prometheus-rules.yml ];

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

          static_configs = map (host: {
            targets = [ "${config.networking.fleet.${host}.ip}:9100" ];
            labels = {
              instance = host;
              host = host;
            };
          }) physicalHosts;
        }

        {
          job_name = "smartctl";

          static_configs = map (host: {
            targets = [ "${config.networking.fleet.${host}.ip}:9633" ];
            labels = {
              instance = host;
              host = host;
            };
          }) physicalHosts;
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

          relabel_configs = blackboxRelabelConfigs;
        }
      ]
      ++ lib.optionals cfg.enablePublicEndpointProbes publicBlackboxScrapeJobs
      ++ lib.optionals (cfg.postgresCaFile != null) [
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

          relabel_configs = blackboxRelabelConfigs;
        }
      ];

      exporters.blackbox = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9115;

        # Run with a fixed identity so it can read its owner-only SOPS CA secret.
        user = "prometheus";
        group = "prometheus";

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
            }
            // lib.optionalAttrs (cfg.postgresCaFile != null) {
              tls_postgres = {
                prober = "tcp";
                timeout = "5s";
                tcp = {
                  preferred_ip_protocol = "ip4";
                  tls = true;
                  tls_config = {
                    ca_file = cfg.postgresCaFile;
                    server_name = "r820.lan";
                  };
                };
              };
            };
          }
        );
      };
    };

    # NixOS exporter services use DynamicUser by default. Disable it so the
    # Blackbox exporter runs as the fixed prometheus user and can read the
    # owner-only SOPS-managed PostgreSQL CA file.
    systemd.services."prometheus-blackbox-exporter".serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "prometheus";
      Group = lib.mkForce "prometheus";
    };
  };
}
