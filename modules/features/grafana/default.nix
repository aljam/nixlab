{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Grafana secrets share the same SOPS source and service identity.
  grafanaSecret = {
    sopsFile = ../../../secrets/monitoring.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  securityDashboard = pkgs.writeTextDir "security-posture.json" (
    builtins.readFile ./assets/security-posture.json
  );

  lokiDashboard = pkgs.writeTextDir "loki.json" (builtins.readFile ./assets/loki.json);

  grafanaPort = config.services.grafana.settings.server.http_port or 3000;
  grafanaExposed = lib.elem grafanaPort config.networking.proxyBackendPorts;
  grafanaAnonymous = config.services.grafana.settings."auth.anonymous".enabled or false;
  grafanaSignup = config.services.grafana.settings.users.allow_sign_up or false;
in
{
  options.services.nixlab.grafana.lokiUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Loki URL to provision as a Grafana datasource, if any.";
  };

  config = {
    sops.secrets."grafana-admin-password" = grafanaSecret;

    sops.secrets."grafana-secret-key" = grafanaSecret;

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
        ];
      };
    };

    networking.proxyBackendPorts = [ 3000 ];

    assertions = [
      # Grafana is internet-facing when included in the HAProxy backend
      # allowlist. It must require authentication and must not permit
      # self-registration.
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
