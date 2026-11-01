{ config, lib, pkgs, ... }:

let
  alertmanagerConfig = pkgs.writeText "alertmanager.yml" ''
    route:
      receiver: ntfy-default
      group_by:
        - alertname
        - host
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - receiver: ntfy-critical
          matchers:
            - 'severity="critical"'

    receivers:
      - name: ntfy-default
        ntfy_configs:
          - url: "@NTFY_URL@"
            priority: default

      - name: ntfy-critical
        ntfy_configs:
          - url: "@NTFY_URL@"
            priority: high
  '';

  renderedConfig = "/var/lib/alertmanager/alertmanager.yml";
in
{
  # Alertmanager remains loopback-only. The ntfy URL, including its private
  # topic and access token if used, is supplied at runtime from SOPS.
  sops.secrets.ntfy-url = {
    sopsFile = ../../secrets/monitoring.yaml;
    owner = "alertmanager";
    group = "alertmanager";
    mode = "0400";
  };

  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";
    configFile = renderedConfig;
  };

  systemd.services.alertmanager = {
    preStart = lib.mkAfter ''
      install -m 0600 /dev/null ${renderedConfig}
      sed "s|@NTFY_URL@|$(cat ${config.sops.secrets.ntfy-url.path})|g" \
        ${alertmanagerConfig} > ${renderedConfig}
    '';
  };

  assertions = [
    {
      assertion = !(lib.elem 9093 config.networking.proxyBackendPorts);
      message = "Alertmanager must not be exposed through the HAProxy backend allowlist.";
    }
  ];
}
