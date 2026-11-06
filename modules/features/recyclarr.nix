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
      };
    };
  };
}
