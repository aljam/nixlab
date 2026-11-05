{ lib, config, pkgs, ... }:

let
  cfg = config.modules.features.prometheus-alerts;
  alertmanagerConfig = pkgs.writeText "alertmanager.yml" (builtins.toJSON {
    route = {
      receiver = "ntfy";
      group_by = [ "alertname" ];
      group_wait = "30s";
      group_interval = "5m";
      repeat_interval = "4h";
    };
    receivers = [
      {
        name = "ntfy";
        webhook_configs = [
          {
            url_file = config.sops.secrets.ntfy-url.path;
          }
        ];
      }
    ];
  });
in
{
  options.modules.features.prometheus-alerts.enable =
    lib.mkEnableOption "Prometheus Alertmanager with ntfy notifications";

  config = lib.mkIf cfg.enable {
    sops.secrets.ntfy-url = {
      sopsFile = ../../secrets/monitoring.yaml;
      owner = "alertmanager";
      group = "alertmanager";
      mode = "0400";
      restartUnits = [ "alertmanager.service" ];
    };

    services.prometheus.alertmanager = {
      enable = true;
      configurationFile = alertmanagerConfig;
    };
  };
}
