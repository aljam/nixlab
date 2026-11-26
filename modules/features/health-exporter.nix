{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.health-exporter;

  exporterScript = pkgs.writers.writePython3 "nixlab-health-exporter" {
    flakeIgnore = [ "E501" ];
  } ''
    import json
    import os
    import subprocess
    import time

    from prometheus_client import start_http_server
    from prometheus_client.core import GaugeMetricFamily, REGISTRY


    class HealthCollector:
        def collect(self):
            tailscale_up = GaugeMetricFamily(
                "nixlab_tailscale_up",
                "Whether the Tailscale daemon is reachable.",
                ["instance"],
            )
            address_configured = GaugeMetricFamily(
                "nixlab_tailscale_address_configured",
                "Whether Tailscale has an assigned address.",
                ["instance"],
            )
            peer_count = GaugeMetricFamily(
                "nixlab_tailscale_peer_count",
                "Number of known Tailscale peers.",
                ["instance"],
            )
            peer_online = GaugeMetricFamily(
                "nixlab_tailscale_peer_online",
                "Number of online Tailscale peers.",
                ["instance"],
            )

            smart_status = GaugeMetricFamily(
                "disk_health_smart_status",
                "SMART health status; 1 healthy, 0 unhealthy.",
                ["instance", "device"],
            )
            pool_state = GaugeMetricFamily(
                "disk_health_zfs_pool_state",
                "ZFS pool state; 0 online, 1 degraded, 2 faulted, 3 unknown.",
                ["instance", "pool"],
            )
            scrub_errors = GaugeMetricFamily(
                "disk_health_zfs_scrub_errors",
                "ZFS scrub errors.",
                ["instance", "pool"],
            )

            backup_result = GaugeMetricFamily(
                "nixlab_restic_backup_last_result",
                "Last Restic backup result; 1 success, 0 failure.",
                ["instance", "job"],
            )
            backup_timestamp = GaugeMetricFamily(
                "nixlab_restic_backup_last_success_timestamp_seconds",
                "Unix timestamp of the last successful Restic backup.",
                ["instance", "job"],
            )
            backup_duration = GaugeMetricFamily(
                "nixlab_restic_backup_duration_seconds",
                "Duration of the last Restic backup in seconds.",
                ["instance", "job"],
            )

            instance = os.uname().nodename

            try:
                status = json.loads(
                    subprocess.check_output(
                        ["tailscale", "status", "--json"],
                        text=True,
                        timeout=10,
                    )
                )
                peers = status.get("Peer", {})
                online = sum(
                    1
                    for peer in peers.values()
                    if peer.get("Online")
                )
                tailscale_up.add_metric([instance], 1)
                address_configured.add_metric(
                    [instance],
                    1 if status.get("TailscaleIPs") else 0,
                )
                peer_count.add_metric([instance], len(peers))
                peer_online.add_metric([instance], online)
            except Exception:
                tailscale_up.add_metric([instance], 0)
                address_configured.add_metric([instance], 0)
                peer_count.add_metric([instance], 0)
                peer_online.add_metric([instance], 0)

            try:
                pools = subprocess.check_output(
                    ["zpool", "list", "-H", "-o", "name,health"],
                    text=True,
                    timeout=10,
                ).splitlines()
                states = {
                    "ONLINE": 0,
                    "DEGRADED": 1,
                    "FAULTED": 2,
                }
                for line in pools:
                    name, health = line.split()[:2]
                    pool_state.add_metric(
                        [instance, name],
                        states.get(health, 3),
                    )
                    scrub_errors.add_metric([instance, name], 0)
            except Exception:
                pass

            state_file = os.environ.get(
                "NIXLAB_BACKUP_ASSURANCE_STATE",
                "/var/lib/nixlab-health-exporter/backup-assurance.json",
            )
            try:
                with open(state_file, encoding="utf-8") as handle:
                    jobs = json.load(handle)
                for job, values in jobs.items():
                    backup_result.add_metric(
                        [instance, job], values.get("last_result", 0)
                    )
                    backup_timestamp.add_metric(
                        [instance, job],
                        values.get("last_success_timestamp_seconds", 0),
                    )
                    backup_duration.add_metric(
                        [instance, job],
                        values.get("duration_seconds", 0),
                    )
            except Exception:
                pass

            yield tailscale_up
            yield address_configured
            yield peer_count
            yield peer_online
            yield smart_status
            yield pool_state
            yield scrub_errors
            yield backup_result
            yield backup_timestamp
            yield backup_duration


    def main():
        REGISTRY.register(HealthCollector())
        start_http_server(int(os.environ.get("NIXLAB_HEALTH_EXPORTER_PORT", "9788")))
        while True:
            time.sleep(3600)


    if __name__ == "__main__":
        main()
  '';
in
{
  options.modules.features.health-exporter = {
    enable = lib.mkEnableOption "NixLab health metrics exporter";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9788;
      description = "Local HTTP port for the NixLab health exporter.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.python3Packages.prometheus-client ];

    systemd.services.nixlab-health-exporter = {
      description = "NixLab health metrics exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${exporterScript}/bin/nixlab-health-exporter";
        Restart = "on-failure";
        RestartSec = "5s";

        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        StateDirectory = "nixlab-health-exporter";

        Environment = [
          "NIXLAB_HEALTH_EXPORTER_PORT=${toString cfg.port}"
        ];
      };
    };
  };
}
