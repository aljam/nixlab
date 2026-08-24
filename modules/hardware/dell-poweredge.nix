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
        PATH=${lib.makeBinPath [ pkgs.ipmitool pkgs.lm_sensors pkgs.gawk pkgs.coreutils ]}

        # Switch Dell iDRAC to manual fan mode
        ${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x01 0x00 > /dev/null 2>&1 || true

        while true; do
          # Get highest CPU core temp
          CPU_TEMP=$(${pkgs.lm_sensors}/bin/sensors | ${pkgs.gawk}/bin/awk '/Core [0-9]+/ {gsub(/[^0-9.]/,"",$3); if($3>max) max=$3} END{print int(max)}')

          # Fallback if sensors fails
          if [ -z "$CPU_TEMP" ] || [ "$CPU_TEMP" -lt 0 ]; then
            CPU_TEMP=50
          fi

          # Aggressive fan curve for proper cooling
          if [ "$CPU_TEMP" -lt 35 ]; then
            FAN_HEX="0x19"    # 25% - quiet idle
          elif [ "$CPU_TEMP" -lt 50 ]; then
            FAN_HEX="0x32"    # 50% - normal load
          elif [ "$CPU_TEMP" -lt 65 ]; then
            FAN_HEX="0x4B"    # 75% - heavy load
          elif [ "$CPU_TEMP" -lt 75 ]; then
            FAN_HEX="0x64"    # 100% - hot
          else
            FAN_HEX="0x64"    # 100% - critical
          fi

          ${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x02 0xff $FAN_HEX > /dev/null 2>&1 || true

          ${pkgs.coreutils}/bin/sleep 5
        done
      '';
      ExecStop = pkgs.writeShellScript "dell-fans-stop" ''
        # Return to automatic control on stop
        ${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x01 0x01 > /dev/null 2>&1 || true
        # Set fans to 100% briefly before returning to auto (safety)
        ${pkgs.ipmitool}/bin/ipmitool raw 0x30 0x30 0x02 0xff 0x64 > /dev/null 2>&1 || true
      '';
    };
  };
}
