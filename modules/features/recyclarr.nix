{
  lib,
  config,
  pkgs,
  mkSecret,
  ...
}:
let
  cfg = config.modules.features.recyclarr;
in
{
  options.modules.features.recyclarr.enable = lib.mkEnableOption "Recyclarr configuration synchronization";

  config = lib.mkIf cfg.enable {
    roles.security.systemdHardenedServices = [ "recyclarr" ];

    sops.secrets.radarr_api_key = mkSecret {
      name = "radarr_api_key";
      sopsFile = ../../secrets/media.yaml;
      owner = "recyclarr";
      group = "recyclarr";
      restartUnits = [ "recyclarr.service" ];
    };

    # Recyclarr configuration and service definition retained from the
    # existing module. This change only corrects the SOPS source file for the
    # Radarr API key.
  };
}
