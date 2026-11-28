{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.features.power-profiles.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable power-profiles-daemon and its desktop integration.";
  };

  config = lib.mkIf config.modules.features.power-profiles.enable {
    # Enable power-profiles-daemon with mkForce to override any conflicting settings
    services.power-profiles-daemon.enable = lib.mkForce true;

    environment.systemPackages = with pkgs; [
      power-profiles-daemon
    ];

    assertions = [
      {
        assertion = !config.services.tlp.enable;
        message = "power-profiles-daemon conflicts with TLP; disable one of them.";
      }
    ];
  };
}
