# Recyclarr configuration synchronization.
#
# The service runs as its dedicated user and needs read access to the generated
# configuration and Radarr API key. It has no persistent writable state.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.recyclarr;
  recyclarrConfig = pkgs.writeText "recyclarr.yml" (
    builtins.toJSON {
      radarr = {
        instance = "radarr";
        base_url = "http://127.0.0.1:7878";
        api_key._secret = config.sops.secrets.radarr_api_key.path;
      };
    }
  );
in
{
  options.modules.features.recyclarr.enable =
    lib.mkEnableOption "Recyclarr configuration synchronization";

  config = lib.mkIf cfg.enable {
    sops.secrets.radarr_api_key = {
      sopsFile = ../../secrets/servarr.yaml;
      owner = "recyclarr";
      group = "recyclarr";
      mode = "0400";
      restartUnits = [ "recyclarr.service" ];
    };

    systemd.services.recyclarr = {
      description = "Recyclarr configuration synchronization";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "recyclarr";
        Group = "recyclarr";
        ExecStart = "${pkgs.recyclarr}/bin/recyclarr sync --config ${recyclarrConfig}";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
    };
  };
}
