{ lib, config, pkgs, ... }:

let
  cfg = config.modules.features.grafana;
in
{
  options.modules.features.grafana.enable =
    lib.mkEnableOption "Grafana monitoring dashboard";

  config = lib.mkIf cfg.enable {
    sops.secrets."grafana-admin-password" = {
      sopsFile = ../../secrets/monitoring.yaml;
      owner = "grafana";
      group = "grafana";
      mode = "0400";
      restartUnits = [ "grafana.service" ];
    };

    sops.secrets."grafana-secret-key" = {
      sopsFile = ../../secrets/monitoring.yaml;
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
          admin_password = "$__file{${config.sops.secrets."grafana-admin-password".path}}";
          secret_key = "$__file{${config.sops.secrets."grafana-secret-key".path}}";
        };
        users = {
          allow_sign_up = false;
        };
        auth.anonymous = {
          enabled = false;
        };
      };
    };
  };
}
