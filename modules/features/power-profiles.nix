{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.modules.features.power-profiles;
in
{
  options.modules.features.power-profiles = {
    enable = mkEnableOption "desktop power-profile management";

    preferredProfile = mkOption {
      type = types.enum [
        "performance"
        "balanced"
        "power-saver"
      ];
      default = "balanced";
      description = "Power profile selected at boot.";
    };

    thermald = {
      enable = mkEnableOption "Intel thermal management";
    };
  };

  config = mkIf cfg.enable {
    services.power-profiles-daemon.enable = true;

    services.thermald.enable = mkIf cfg.thermald.enable true;

    # Select the configured profile after the daemon starts. This avoids
    # relying on a desktop session being active.
    systemd.services.power-profile-default = {
      description = "Set the configured power profile";
      after = [ "power-profiles-daemon.service" ];
      wants = [ "power-profiles-daemon.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.power-profiles-daemon} set ${cfg.preferredProfile}";
        RemainAfterExit = true;
      };
    };
  };
}
