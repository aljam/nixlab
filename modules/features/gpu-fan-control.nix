{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.gpuFanControl;

  fanControlScript = pkgs.writeShellScript "gpu-fan-control" ''
    set -euo pipefail

    last_duty=0

    set_fans() {
      local duty=$1
      local duty_hex
      duty_hex=$(printf '%02x' "$duty")

      ${pkgs.ipmitool}/bin/ipmitool -I open raw 0x30 0x30 0x01 0x00
      ${pkgs.ipmitool}/bin/ipmitool -I open raw 0x30 0x30 0x02 0xff "0x$duty_hex"
      last_duty=$duty
    }

    restore_automatic() {
      ${pkgs.ipmitool}/bin/ipmitool -I open raw 0x30 0x30 0x01 0x01 || true
    }

    trap restore_automatic EXIT

    while true; do
      if ! temps=$(${config.hardware.nvidia.package}/bin/nvidia-smi \
        --query-gpu=temperature.gpu \
        --format=csv,noheader,nounits 2>/dev/null); then
        echo "Unable to read NVIDIA GPU temperatures; restoring automatic fan control" >&2
        restore_automatic
        sleep ${toString cfg.interval}
        continue
      fi

      if [ -z "$temps" ]; then
        echo "No NVIDIA GPU temperatures returned; restoring automatic fan control" >&2
        restore_automatic
        sleep ${toString cfg.interval}
        continue
      fi

      max_temp=$(printf '%s\n' "$temps" | sort -n | tail -1)

      if [ "$max_temp" -ge 85 ]; then
        target_duty=100
      elif [ "$max_temp" -ge 80 ]; then
        target_duty=75
      elif [ "$max_temp" -ge 70 ]; then
        target_duty=60
      elif [ "$max_temp" -ge 60 ]; then
        target_duty=45
      else
        target_duty=${toString cfg.minDuty}
      fi

      # Avoid rapid fan-speed oscillation: only lower the duty after the
      # temperature has dropped below the next lower threshold.
      if [ "$target_duty" -lt "$last_duty" ]; then
        case "$last_duty" in
          45) required_temp=57 ;;
          60) required_temp=67 ;;
          75) required_temp=77 ;;
          100) required_temp=82 ;;
          *) required_temp=0 ;;
        esac

        if [ "$max_temp" -ge "$required_temp" ]; then
          target_duty=$last_duty
        fi
      fi

      if [ "$target_duty" -ne "$last_duty" ]; then
        echo "GPU temperature ''${max_temp}C; setting fans to ''${target_duty}%"
        set_fans "$target_duty"
      fi

      sleep ${toString cfg.interval}
    done
  '';
in
{
  options.modules.features.gpuFanControl = {
    enable = lib.mkEnableOption "GPU temperature-based Dell IPMI fan control";

    interval = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Fan-control polling interval in seconds.";
    };

    minDuty = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Minimum manual fan duty percentage.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.gpu-fan-control = {
      description = "GPU temperature-based Dell IPMI fan control";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${fanControlScript}";
        Restart = "on-failure";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
  };
}
