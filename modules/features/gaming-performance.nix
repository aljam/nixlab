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
    enable = lib.mkEnableOption "vendor-agnostic gaming performance tuning";
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
  };
}
