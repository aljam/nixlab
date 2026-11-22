{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.disk-health;

  textfileDirectory = config.modules.features.node-exporter.textfileDirectory;

  smartctl = lib.getExe pkgs.smartmontools;
  jq = lib.getExe pkgs.jq;

  diskHealthExporter = pkgs.writers.writeBash "disk-health-exporter" ''
    set -euo pipefail

    output="${textfileDirectory}/disk-health.prom"
    tmp="$output.tmp"

    : > "$tmp"

    add_metric() {
      local metric="$1"
      local labels="$2"
      local value="$3"
      printf '%s%s %s\n' "$metric" "$labels" "$value" >> "$tmp"
    }

    for device in $DEVICES; do
      if ${smartctl} --health --json "$device" | ${jq} -e '.smart_status.passed == true' >/dev/null; then
        smart_status=1
      else
        smart_status=0
      fi

      add_metric disk_health_smart_status "{device=\"$device\"}" "$smart_status"
    done

    while IFS=$'\t' read -r pool health; do
      case "$health" in
        ONLINE) pool_state=0 ;;
        DEGRADED) pool_state=1 ;;
        FAULTED|UNAVAIL|OFFLINE) pool_state=2 ;;
        *) pool_state=3 ;;
      esac

      add_metric disk_health_zfs_pool_state "{pool=\"$pool\"}" "$pool_state"

      if zpool status "$pool" | grep -q 'No known data errors'; then
        scrub_errors=0
      else
        scrub_errors=1
      fi

      add_metric disk_health_zfs_scrub_errors "{pool=\"$pool\"}" "$scrub_errors"
    done < <(zpool list -H -o name,health)

    mv "$tmp" "$output"
  '';

  smartSelfTest = pkgs.writers.writeBash "smart-self-test" ''
    set -euo pipefail

    for device in $DEVICES; do
      ${smartctl} -t short "$device"
    done
  '';
in
{
  options.modules.features.disk-health = {
    enable = lib.mkEnableOption "SMART and ZFS disk-health monitoring";

    devices = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Block devices to monitor with smartctl, for example `/dev/disk/by-id/...`.
        Leave empty to monitor only ZFS pools.
      '';
    };

    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = ''
        systemd duration between metric refreshes, for example `15min`.
        Used with `OnUnitActiveSec`.
      '';
    };

    smartSelfTestSchedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 03:00:00";
      description = "systemd calendar expression for SMART short self-tests.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.prometheus.exporters.node.enable;
        message = "modules.features.disk-health requires modules.features.node-exporter.";
      }
    ];

    services.smartd.enable = true;

    systemd.services.disk-health-exporter = {
      description = "Publish SMART and ZFS disk-health metrics for node_exporter";
      after = [ "multi-user.target" ];
      requires = [ "prometheus-node-exporter.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${diskHealthExporter}";

        User = "root";
        Group = "root";

        Environment = [
          "DEVICES=${lib.concatStringsSep " " cfg.devices}"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ textfileDirectory ];
        CapabilityBoundingSet = [ ];
      };
    };

    systemd.timers.disk-health-exporter = {
      description = "Refresh SMART and ZFS disk-health metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.scrapeInterval;
        RandomizedDelaySec = "5m";
        Persistent = true;
      };
    };

    systemd.services.smartd-selftest = {
      description = "Run SMART short self-tests";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${smartSelfTest}";

        Environment = [
          "DEVICES=${lib.concatStringsSep " " cfg.devices}"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        CapabilityBoundingSet = [ ];
      };
    };

    systemd.timers.smartd-selftest = lib.mkIf (cfg.devices != [ ]) {
      description = "Schedule SMART short self-tests";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.smartSelfTestSchedule;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    services.prometheus.ruleGroups = [
      {
        name = "disk-health";
        rules = [
          {
            alert = "DiskSmartFailure";
            expr = ''disk_health_smart_status == 0'';
            for = "10m";
            labels = {
              severity = "critical";
            };
            annotations = {
              summary = "SMART health check failed";
              description = ''SMART reports an unhealthy or unresponsive disk on {{ $labels.device }}.'';
            };
          }

          {
            alert = "ZfsPoolDegraded";
            expr = ''disk_health_zfs_pool_state > 0'';
            for = "5m";
            labels = {
              severity = "critical";
            };
            annotations = {
              summary = "ZFS pool is not fully healthy";
              description = ''ZFS pool {{ $labels.pool }} is in a non-online state.'';
            };
          }

          {
            alert = "ZfsDataErrors";
            expr = ''disk_health_zfs_scrub_errors > 0'';
            for = "5m";
            labels = {
              severity = "critical";
            };
            annotations = {
              summary = "ZFS pool reports data errors";
              description = ''ZFS pool {{ $labels.pool }} reports errors other than "No known data errors".'';
            };
          }
        ];
      }
    ];
  };
}
