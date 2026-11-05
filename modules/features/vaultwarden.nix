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

      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = "8222";
        SIGNUPS_ALLOWED = "false";
        DOMAIN = "https://vault.derezzed.info";
        ADMIN_TOKEN_FILE = config.sops.secrets."vaultwarden-admin-token".path;
        ADMIN_RATELIMIT_SECONDS = "60";
        ADMIN_RATELIMIT_MAX_BURST = "3";
      };
    };
  };
}
