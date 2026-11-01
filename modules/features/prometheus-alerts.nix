{ config, lib, pkgs, ... }:

let
  relayPort = 9095;

  ntfyAlertRelay = pkgs.writers.writePython3 "ntfy-alert-relay" { } ''
    import json
    import os
    import sys
    import urllib.parse
    import urllib.request
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    with open(os.environ["NTFY_URL_FILE"], "r", encoding="utf-8") as handle:
        NTFY_URL = handle.read().strip()


    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            try:
                length = int(self.headers.get("Content-Length", "0"))
                payload = json.loads(self.rfile.read(length))
                parsed = urllib.parse.urlparse(self.path)
                query = urllib.parse.parse_qs(parsed.query)
                priority = query.get("priority", ["default"])[0]

                for alert in payload.get("alerts", []):
                    labels = alert.get("labels", {})
                    annotations = alert.get("annotations", {})
                    title = labels.get("alertname", "Prometheus alert")

                    if alert.get("status") == "resolved":
                        title = "RESOLVED: " + title

                    body = annotations.get("description", "")
                    request = urllib.request.Request(
                        NTFY_URL,
                        data=body.encode("utf-8"),
                        headers={
                            "X-Title": title,
                            "X-Priority": priority,
                        },
                        method="POST",
                    )
                    urllib.request.urlopen(request, timeout=10).read()
            except Exception as exc:
                print("alert relay error:", exc, flush=True)
            finally:
                self.send_response(200)
                self.end_headers()

        def log_message(self, *args):
            pass


    ThreadingHTTPServer(
        ("127.0.0.1", int(sys.argv[1])), Handler
    ).serve_forever()
  '';
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

    configuration = {
      route = {
        receiver = "ntfy-default";
        group_by = [ "alertname" "host" ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "4h";

        routes = [
          {
            receiver = "ntfy-critical";
            matchers = [ "severity=\"critical\"" ];
          }
        ];
      };

      receivers = [
        {
          name = "ntfy-default";
          webhook_configs = [
            {
              url = "http://127.0.0.1:${toString relayPort}/alerts";
            }
          ];
        }

        {
          name = "ntfy-critical";
          webhook_configs = [
            {
              url = "http://127.0.0.1:${toString relayPort}/alerts?priority=high";
            }
          ];
        }
      ];
    };
  };

  systemd.services.ntfy-alert-relay = {
    description = "Alertmanager to ntfy notification relay";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      NTFY_URL_FILE = config.sops.secrets.ntfy-url.path;
    };

    serviceConfig = {
      ExecStart = "${ntfyAlertRelay} ${toString relayPort}";
      User = "alertmanager";
      Group = "alertmanager";
      Restart = "on-failure";
      RestartSec = "5s";

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      LockPersonality = true;
    };
  };

  assertions = [
    {
      assertion = !(lib.elem 9093 config.networking.proxyBackendPorts);
      message = "Alertmanager must not be exposed through the HAProxy backend allowlist.";
    }
    {
      assertion = !(lib.elem relayPort config.networking.proxyBackendPorts);
      message = "The ntfy alert relay must not be exposed through the HAProxy backend allowlist.";
    }
  ];
}
