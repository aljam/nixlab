{
  config,
  lib,
  pkgs,
  mkSecret,
  ...
}:
let
  relayPort = 9095;

  ntfyAlertRelay = pkgs.writers.writePython3 "ntfy-alert-relay" { } ''
    import json
    import os
    import sys
    import urllib.parse
    import urllib.request
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    # The SOPS secret is named `ntfy-url`. Its decrypted path is exposed to
    # the relay through NTFY_URL_FILE; the URL itself is never placed in the
    # unit environment.
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
                tags = query.get("tags", [""])[0]

                for alert in payload.get("alerts", []):
                    labels = alert.get("labels", {})
                    annotations = alert.get("annotations", {})
                    title = labels.get("alertname", "Prometheus alert")
                    severity = labels.get("severity", "info")

                    if alert.get("status") == "resolved":
                        title = "RESOLVED: " + title

                    body = annotations.get("description", "")
                    if severity:
                        body = f"Severity: {severity}\n\n{body}".strip()

                    headers = {
                        "X-Title": title,
                        "X-Priority": priority,
                    }

                    if tags:
                        headers["X-Tags"] = tags

                    request = urllib.request.Request(
                        NTFY_URL,
                        data=body.encode("utf-8"),
                        headers=headers,
                        method="POST",
                    )
                    urllib.request.urlopen(request, timeout=10).read()
                status = 200
            except Exception as exc:
                print("alert relay error:", exc, flush=True)
                # Alertmanager retries a webhook only on a 5xx response.
                status = 502

            self.send_response(status)
            self.end_headers()

        def log_message(self, *args):
            pass


    ThreadingHTTPServer(
        ("127.0.0.1", int(sys.argv[1])), Handler
    ).serve_forever()
  '';

  severityPolicy = {
    critical = {
      priority = "high";
      tags = "rotating_light,skull";
      groupWait = "0s";
      groupInterval = "5m";
      repeatInterval = "30m";
    };
    warning = {
      priority = "default";
      tags = "warning";
      groupWait = "2m";
      groupInterval = "15m";
      repeatInterval = "4h";
    };
    info = {
      priority = "low";
      tags = "information_source";
      groupWait = "10m";
      groupInterval = "1h";
      repeatInterval = "24h";
    };
  };

  mkSeverityRoute = severity: {
    receiver = "ntfy-${severity}";
    matchers = [ "severity=\"${severity}\"" ];
    group_wait = severityPolicy.${severity}.groupWait;
    group_interval = severityPolicy.${severity}.groupInterval;
    repeat_interval = severityPolicy.${severity}.repeatInterval;
    continue = false;
  };

  mkSeverityReceiver = severity: {
    name = "ntfy-${severity}";
    webhook_configs = [
      {
        url = "http://127.0.0.1:${toString relayPort}/alerts?priority=${
          severityPolicy.${severity}.priority
        }&tags=${severityPolicy.${severity}.tags}";
        send_resolved = true;
      }
    ];
  };
in
{
  # Alertmanager uses a dynamic user by default, which is unavailable while
  # SOPS installs secrets during activation. Use a stable service identity so
  # the relay can own and read its secret.
  users.groups.alertmanager = { };

  users.users.alertmanager = {
    isSystemUser = true;
    group = "alertmanager";
  };

  # The ntfy URL, including its private topic and access token if used, is
  # supplied at runtime from SOPS.
  sops.secrets.ntfy-url = mkSecret {
    name = "ntfy-url";
    sopsFile = ../../secrets/monitoring.yaml;
    owner = "alertmanager";
    group = "alertmanager";
    restartUnits = [ "ntfy-alert-relay.service" ];
  };

  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";
    # A single instance has no peers. Without this flag Alertmanager also
    # opens its gossip listener on 0.0.0.0:9094 (TCP and UDP).
    extraFlags = [ "--cluster.listen-address=" ];

    configuration = {
      route = {
        receiver = "ntfy-default";
        group_by = [
          "alertname"
          "host"
        ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "24h";

        routes = map mkSeverityRoute [
          "critical"
          "warning"
          "info"
        ];
      };

      inhibit_rules = [
        {
          source_matchers = [ "severity=\"critical\"" ];
          target_matchers = [ "severity=\"warning\"" ];
          equal = [
            "alertname"
            "host"
          ];
        }
      ];

      receivers = [
        {
          name = "ntfy-default";
          webhook_configs = [
            {
              url = "http://127.0.0.1:${toString relayPort}/alerts";
              send_resolved = true;
            }
          ];
        }
      ]
      ++ map mkSeverityReceiver [
        "critical"
        "warning"
        "info"
      ];
    };
  };

  roles.security.systemdHardenedServices = [ "ntfy-alert-relay" ];

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
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
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
