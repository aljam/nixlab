{ lib, config, pkgs, ... }:

let
  cfg = config.modules.features.vaultwarden;
in
{
  options.modules.features.vaultwarden.enable =
    lib.mkEnableOption "Vaultwarden password manager";

  config = lib.mkIf cfg.enable {
    sops.secrets."vaultwarden-admin-token" = {
      sopsFile = ../../secrets/vaultwarden.yaml;
      owner = "vaultwarden";
      group = "vaultwarden";
      mode = "0400";
      restartUnits = [ "vaultwarden.service" ];
    };

    services.vaultwarden = {
      enable = true;
      environmentFile = pkgs.writeText "vaultwarden.env" ''
        ADMIN_TOKEN_FILE=${config.sops.secrets."vaultwarden-admin-token".path}
        SIGNUPS_ALLOWED=false
      '';
    };
  };
}
