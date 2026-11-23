{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.gaming-performance;
in
{
  options.modules.features.gaming-performance = {
    enable = lib.mkEnableOption "opt-in gaming performance tuning";

    cpuGovernor = lib.mkOption {
      type = lib.types.enum [
        "performance"
        "schedutil"
      ];
      default = "performance";
      description = "CPU governor applied when a compatible CPU frequency driver is present.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.features.power-profiles.enable or false;
        message = "modules.features.gaming-performance requires modules.features.power-profiles.";
      }
    ];

    programs.gamemode = {
      enable = true;

      settings = {
        general.renice = 10;

        custom = {
          start = "${lib.getExe pkgs.power-profiles-daemon} set performance";
          end = "${lib.getExe pkgs.power-profiles-daemon} set balanced";
        };
      };
    };

    services.udev.extraRules = ''
      # Prefer the configured CPU governor when a compatible cpufreq driver
      # exposes it. This is harmless on systems without scaling_governor.
      ACTION=="add", SUBSYSTEM=="cpu", TEST=="cpufreq/scaling_governor", ATTR{cpufreq/scaling_governor}="${cfg.cpuGovernor}"
    '';
  };
}
