{ config, lib, pkgs, ... }:
let
  cfg = config.modules.features.tailscale-health;
  textfileDirectory = config.modules.features.node-exporter.textfileDirectory;
in
{
  imports = [
    ./node-exporter.nix
  ];

  options.modules.features.tailscale-health = {
    enable = lib.mkEnableOption "Tailscale client health metrics";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nixlab-tailscale-health = {
      description = "Publish Tailscale client metrics for node_exporter";
      wantedBy = [ "timers.target" ];
      after = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.tailscale}/bin/tailscale metrics write ${textfileDirectory}/tailscale.prom";
        User = "root";
        Group = "root";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";

        ReadWritePaths = [
          textfileDirectory
        ];
      };
    };

    systemd.timers.nixlab-tailscale-health = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* *:*:00";
        AccuracySec = "15s";
        Persistent = true;
        Unit = "nixlab-tailscale-health.service";
      };
    };
  };
}
