{
  config,
  lib,
  pkgs,
  mkSecret,
  ...
}:

let
  grafanaPort = config.services.grafana.settings.server.http_port or 3000;
  grafanaExposed = lib.elem grafanaPort config.networking.proxyBackendPorts;
  grafanaAnonymous = config.services.grafana.settings."auth.anonymous".enabled or false;
  grafanaSignup = config.services.grafana.settings.users.allow_sign_up or false;

  securityDashboard = pkgs.writeTextDir "security-posture.json" (
    builtins.readFile ./assets/security-posture.json
  );

  lokiDashboard = pkgs.writeTextDir "loki.json" (builtins.readFile ./assets/loki.json);

  diskHealthDashboard = pkgs.writeTextDir "disk-health.json" (
    builtins.readFile ./assets/disk-health.json
  );

  serverInventoryDashboard = pkgs.writeTextDir "server-inventory.json" (
    builtins.readFile ./assets/server-inventory.json
  );

  tailscaleDashboard = pkgs.writeTextDir "tailscale.json" (builtins.readFile ./assets/tailscale.json);

  fleetCurrencyDashboard = pkgs.writeTextDir "fleet-currency.json" (
    builtins.readFile ./assets/fleet-currency.json
  );
in
{
  imports = [ ./backup-assurance.nix ];

  options.services.nixlab.grafana.lokiUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Loki URL to provision as a Grafana datasource, if any.";
  };

  config = {
    sops.secrets."grafana-admin-password" = mkSecret {
      name = "grafana-admin-password";
      sopsFile = ../../../secrets/monitoring.yaml;
      owner = "grafana";
      group = "grafana";
      mode = "0400";
      restartUnits = [ "grafana.service" ];
    };

    sops.secrets."grafana-secret-key" = mkSecret {
      name = "grafana-secret-key";
      sopsFile = ../../../secrets/monitoring.yaml;
      owner = "grafana";
      group = "grafana";
      mode = "0400";
      restartUnits = [ "grafana.service" ];
    };

    services.grafana = {
      enable = true;

      settings = {
        server = {
          http_addr = config.networking.servicesBindAddress;
          http_port = 3000;
        };

        security = {
          admin_user = "aljam";
          admin_password = "$__file{/run/secrets/grafana-admin-password}";
          secret_key = "$__file{/run/secrets/grafana-secret-key}";
        };

        "auth.anonymous".enabled = false;

        users.allow_sign_up = false;

        log.filters = "search-manifest-watcher:error";
      };

      provision.datasources.settings = {
        apiVersion = 1;

        deleteDatasources = [
          {
            name = "Prometheus";
            orgId = 1;
          }
          {
            name = "Loki";
            orgId = 1;
          }
        ];

        datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://${config.networking.servicesBindAddress}:9090";
            isDefault = true;
            editable = false;
          }
        ]
        ++ lib.optionals (config.services.nixlab.grafana.lokiUrl != null) [
          {
            name = "Loki";
            uid = "loki";
            type = "loki";
            access = "proxy";
            url = config.services.nixlab.grafana.lokiUrl;
            editable = false;
          }
        ];
      };

      provision.dashboards.settings = {
        apiVersion = 1;

        providers = [
          {
            name = "NixLab security";
            options = {
              path = securityDashboard;
              foldersFromFilesStructure = false;
            };
          }

          {
            name = "NixLab logs";
            options = {
              path = lokiDashboard;
              foldersFromFilesStructure = false;
            };
          }

          {
            name = "NixLab disk health";
            options = {
              path = diskHealthDashboard;
              foldersFromFilesStructure = false;
            };
          }

          {
            name = "NixLab server inventory";
            options = {
              path = serverInventoryDashboard;
              foldersFromFilesStructure = false;
            };
          }

          {
            name = "NixLab Tailscale";
            options = {
              path = tailscaleDashboard;
              foldersFromFilesStructure = false;
            };
          }

          {
            name = "NixLab deployment freshness";
            options = {
              path = fleetCurrencyDashboard;
              foldersFromFilesStructure = false;
            };
          }
        ];
      };
    };

    systemd.services.grafana.serviceConfig = {
      ReadWritePaths = [ "/var/lib/grafana" ];
    };

    networking.proxyBackendPorts = [ 3000 ];

    assertions = [
      {
        assertion = !grafanaExposed || !grafanaAnonymous;
        message = "Grafana must disable anonymous access when exposed through the HAProxy backend allowlist.";
      }

      {
        assertion = !grafanaExposed || !grafanaSignup;
        message = "Grafana must disable self-registration when exposed through the HAProxy backend allowlist.";
      }
    ];
  };
}
