{
  config,
  lib,
  pkgs,
  ...
}:

let
  relayPort = 9095;

  backupUnits = [
    "restic-backup-postgresql"
    "restic-backup-matrix-media"
    "restic-backup-vaultwarden"
  ];

  backupUnitRegex = builtins.concatStringsSep "|" backupUnits;

  prometheusRules = ''
    groups:
      - name: backup-health
        rules:
          - alert: ResticBackupJobFailed
            expr: systemd_unit_state{name=~"(${backupUnitRegex})\\.service",state="failed"} == 1
            for: 5m
            labels:
              severity: critical
            annotations:
              description: >-
                Restic backup job {{ $labels.name }} has been failed for more
                than 5 minutes on {{ $labels.instance }}.

          - alert: ResticBackupStale
            expr: time() - node_systemd_unit_last_success_timestamp_seconds{name=~"(${backupUnitRegex})\\.timer"} > 90000
            for: 15m
            labels:
              severity: warning
            annotations:
              description: >-
                Restic backup timer {{ $labels.name }} has not completed
                successfully for more than 25 hours on {{ $labels.instance }}.
  '';

  ntfyAlertRelay = pkgs.writers.writePython3 "ntfy-alert-relay" { } ''
    import json
    import os
    import sys
    import urllib.parse
    import urllib.request
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    # The SOPS secret is intentionally named `nfty-url` to match the existing
    # encrypted monitoring secret. Its decrypted path is exposed to the relay
    # through NFTY_URL_FILE; the URL itself is never placed in the unit
    # environment.
    with open(os.environ["NFTY_URL_FILE"], "r", encoding="utf-8") as handle:
        NFTY_URL = handle.read().strip()


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
                        NFTY_URL,
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
  # Alertmanager uses a dynamic user by default, which is unavailable while
  # SOPS installs secrets during activation. Use a stable service identity so
  # the relay can own and read its secret.
  users.groups.alertmanager = { };

  users.users.alertmanager = {
    isSystemUser = true;
    group = "alertmanager";
  };

  # Alertmanager remains loopback-only. The ntfy URL, including its private
  # topic and access token if used, is supplied at runtime from SOPS.
  sops.secrets.nfty-url = {
    sopsFile = ../../secrets/monitoring.yaml;
    owner = "alertmanager";
    group = "alertmanager";
    mode = "0400";
    restartUnits = [ "ntfy-alert-relay.service" ];
  };

  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";

    configuration = {
      route = {
        receiver = "ntfy-default";
        group_by = [
          "alertname"
          "host"
        ];
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

  services.prometheus.rules = [ prometheusRules ];

  systemd.services.ntfy-alert-relay = {
    description = "Alertmanager to ntfy notification relay";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      NFTY_URL_FILE = config.sops.secrets.nfty-url.path;
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
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
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
