{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.health-exporter;

  exporterScript = pkgs.writers.writePython3 "nixlab-health-exporter" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./health-exporter.py);
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
