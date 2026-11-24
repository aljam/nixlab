{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.drift-monitoring;

  expectedRevision = cfg.expectedRevision;

  driftScript = pkgs.writeShellScript "nixlab-drift-metrics" ''
    set -euo pipefail

    output="''${NODE_EXPORTER_TEXTFILE_DIR}/nixlab-drift.prom"
    tmp="''${output}.tmp"

    mkdir -p "$(dirname "$output")"
    : > "$tmp"

    current_revision="$(nixos-version --configuration-revision 2>/dev/null || true)"

    if [[ -z "$current_revision" ]]; then
      echo 'nixlab_deployment_revision_unknown 1' >> "$tmp"
    elif [[ "$current_revision" == "${expectedRevision}" ]]; then
      echo 'nixlab_drift_revision_mismatch 0' >> "$tmp"
    else
      echo 'nixlab_drift_revision_mismatch 1' >> "$tmp"
    fi

    activation_epoch="$(stat -c %Y /run/current-system)"
    now_epoch="$(date +%s)"
    deployment_age=$((now_epoch - activation_epoch))
    generation="$(basename "$(readlink -f /run/current-system)" | sed 's/^system-//')"

    cat >> "$tmp" <<EOF
nixlab_deployment_activation_timestamp_seconds $activation_epoch
nixlab_deployment_age_seconds $deployment_age
nixlab_deployment_generation{generation="$generation"} 1
EOF

    failed_critical_units=0

    for unit in ''${criticalUnits[@]}; do
      if ! systemctl is-active --quiet "$unit"; then
        failed_critical_units=$((failed_critical_units + 1))
      fi
    done

    echo "nixlab_drift_failed_critical_units $failed_critical_units" >> "$tmp"

    unexpected_tcp_ports=0

    for port in ''${allowedTcpPorts[@]}; do
      if ! ss -lntu "sport = :$port" | grep -q LISTEN; then
        unexpected_tcp_ports=$((unexpected_tcp_ports + 1))
      fi
    done

    echo "nixlab_drift_unexpected_tcp_ports $unexpected_tcp_ports" >> "$tmp"

    unexpected_udp_ports=0

    for port in ''${allowedUdpPorts[@]}; do
      if ! ss -lnu "sport = :$port" | grep -q UNCONN; then
        unexpected_udp_ports=$((unexpected_udp_ports + 1))
      fi
    done

    echo "nixlab_drift_unexpected_udp_ports $unexpected_udp_ports" >> "$tmp"

    mv "$tmp" "$output"
  '';
in
{
  options.modules.features.drift-monitoring = {
    enable = lib.mkEnableOption "NixLab drift monitoring";

    expectedRevision = lib.mkOption {
      type = lib.types.str;
      description = "Git revision that this host is expected to run.";
    };

    criticalUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd units whose failure should be reported as drift.";
    };

    allowedTcpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "TCP ports that must be listening.";
    };

    allowedUdpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "UDP ports that must be listening.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nixlab-drift-metrics = {
      description = "Collect NixLab drift and deployment freshness metrics";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = driftScript;
        Environment = [
          "NODE_EXPORTER_TEXTFILE_DIR=/var/lib/node-exporter/textfile"
          "criticalUnits=${lib.concatStringsSep " " cfg.criticalUnits}"
          "allowedTcpPorts=${lib.concatMapStringsSep " " toString cfg.allowedTcpPorts}"
          "allowedUdpPorts=${lib.concatMapStringsSep " " toString cfg.allowedUdpPorts}"
        ];
        StateDirectory = "node-exporter";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/node-exporter/textfile" ];
      };
    };

    systemd.timers.nixlab-drift-metrics = {
      description = "Collect NixLab drift and deployment freshness metrics";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        AccuracySec = "1min";
        RandomizedDelaySec = "30";
      };
    };
  };
}
