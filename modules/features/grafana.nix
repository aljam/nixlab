{ config, lib, pkgs, ... }:

let
  securityDashboard = pkgs.writeText "security-posture.json" (builtins.readFile ./grafana/security-posture.json);
in
{
  sops.secrets."grafana-admin-password" = {
    sopsFile = ../../secrets/monitoring.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  sops.secrets."grafana-secret-key" = {
    sopsFile = ../../secrets/monitoring.yaml;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
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
      users = {
        allow_sign_up = false;
      };
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
            isDefault = true;
            editable = false;
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "NixLab security";
            options = {
              path = securityDashboard;
              foldersFromFilesStructure = false;
            };
          }
        ];
      };
    };
  };

  networking.proxyBackendPorts = [ 3000 ];
}
