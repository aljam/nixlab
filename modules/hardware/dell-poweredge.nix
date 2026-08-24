{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    ipmitool
    lm_sensors
    gawk
    coreutils
  ];

  systemd.services.dell-fans = {
    description = "Dell PowerEdge Dynamic CPU Fan Control";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";

      ExecStart = pkgs.writeShellScript "dell-fans-loop" ''
        PATH=${lib.makeBinPath [
          pkgs.ipmitool
          pkgs.lm_sensors
          pkgs.gawk
          pkgs.coreutils
        ]}

        # Enable manual fan control.
        ${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x01 0x00 \
          > /dev/null 2>&1 || true

        LAST_FAN_HEX=""

        while true; do
          CPU_TEMP=$(
            ${pkgs.lm_sensors}/bin/sensors |
              ${pkgs.gawk}/bin/awk '
                /Core [0-9]+/ {
                  gsub(/[^0-9.]/, "", $3)
                  if ($3 > max) max = $3
                }
                END {
                  if (max != "") print int(max)
                }
              '
          )

          # Conservative fallback if lm_sensors returns no usable value.
          if [ -z "$CPU_TEMP" ] || [ "$CPU_TEMP" -lt 0 ]; then
            CPU_TEMP=45
          fi

          # Quieter curve:
          #   <45 C  -> 18%
          #   <55 C  -> 22%
          #   <65 C  -> 30%
          #   <72 C  -> 45%
          #   <80 C  -> 65%
          #   >=80 C -> 100%
          #
          # Values are percentages represented as hexadecimal PWM values.
          if [ "$CPU_TEMP" -lt 45 ]; then
            FAN_HEX="0x12"   # 18%
          elif [ "$CPU_TEMP" -lt 55 ]; then
            FAN_HEX="0x16"   # 22%
          elif [ "$CPU_TEMP" -lt 65 ]; then
            FAN_HEX="0x1E"   # 30%
          elif [ "$CPU_TEMP" -lt 72 ]; then
            FAN_HEX="0x2D"   # 45%
          elif [ "$CPU_TEMP" -lt 80 ]; then
            FAN_HEX="0x41"   # 65%
          else
            FAN_HEX="0x64"   # 100%
          fi

          # Only issue an IPMI command when the selected speed changes.
          if [ "$FAN_HEX" != "$LAST_FAN_HEX" ]; then
            ${pkgs.ipmitool}/bin/ipmitool raw \
              0x30 0x30 0x02 0xff "$FAN_HEX" \
              > /dev/null 2>&1 || true

            LAST_FAN_HEX="$FAN_HEX"
          fi

          ${pkgs.coreutils}/bin/sleep 10
        done
      '';

      ExecStop = pkgs.writeShellScript "dell-fans-stop" ''
        # Return control to the iDRAC thermal algorithm.
        ${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x01 0x01 \
          > /dev/null 2>&1 || true
      '';
    };
  };
}
