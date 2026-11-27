{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixlab.desktopSyncMonitoring;
in
{
  options.nixlab.desktopSyncMonitoring = {
    enable = lib.mkEnableOption "desktop file synchronization and system monitoring";

    syncthingUser = lib.mkOption {
      type = lib.types.str;
      description = "User account that runs Syncthing.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      mission-center
      syncthing
    ];

    services.syncthing = {
      enable = true;
      user = cfg.syncthingUser;
      dataDir = "/home/${cfg.syncthingUser}/.local/share/syncthing";
      configDir = "/home/${cfg.syncthingUser}/.config/syncthing";

      settings = {
        gui = {
          enabled = true;
          address = "127.0.0.1:8384";
        };
      };

      overrideDevices = false;
      overrideFolders = false;
    };
  };
}
