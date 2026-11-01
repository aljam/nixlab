{ config, lib, ... }:

# Alertmanager is intentionally UI-only for now: alerts are visible in
# Prometheus and Alertmanager, but no external notification receiver is
# configured. Add a webhook, ntfy, or SMTP receiver later.
#
# Alertmanager must remain loopback-only. It is not added to
# `networking.proxyBackendPorts`, so it is not reachable through HAProxy.
{
  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";

    configuration = {
      route = {
        receiver = "default";
        group_by = [ "alertname" "host" ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "4h";
      };

      receivers = [
        {
          name = "default";
        }
      ];
    };
  };

  config.assertions = [
    {
      assertion = !(lib.elem 9093 config.networking.proxyBackendPorts);
      message = "Alertmanager must not be exposed through the HAProxy backend allowlist.";
    }
  ];
}
