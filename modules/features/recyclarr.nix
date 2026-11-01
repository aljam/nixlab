# Recyclarr - Automated TRaSH-Guides configuration for Radarr and Sonarr.
#
# Exposure model:
# - Recyclarr is a local scheduled job and does not listen on the network.
# - It requires the local Servarr stack because it connects to Radarr and
#   Sonarr on loopback.
# - API keys are loaded from `secrets/media.yaml` through systemd credentials;
#   they are not copied into the Nix store.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.modules.features.recyclarr = {
    enable = lib.mkEnableOption "Recyclarr TRaSH-Guides automation";
  };

  config = lib.mkIf config.modules.features.recyclarr.enable {
    assertions = [
      {
        assertion = config.servarr.enable;
        message = "modules.features.recyclarr requires servarr.enable because it connects to local Radarr and Sonarr.";
      }
    ];

    sops.secrets = {
      radarr_api_key = {
        sopsFile = ../../secrets/media.yaml;
        owner = "recyclarr";
        group = "recyclarr";
        mode = "0400";
      };

      sonarr_api_key = {
        sopsFile = ../../secrets/media.yaml;
        owner = "recyclarr";
        group = "recyclarr";
        mode = "0400";
      };
    };

    services.recyclarr = {
      enable = true;

      configuration = {
        radarr = {
          radarr = {
            base_url = "http://127.0.0.1:7878";
            api_key._secret = config.sops.secrets.radarr_api_key.path;
          };
        };

        sonarr = {
          sonarr = {
            base_url = "http://127.0.0.1:8989";
            api_key._secret = config.sops.secrets.sonarr_api_key.path;
          };
        };
      };
    };

    systemd.timers.recyclarr = {
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
