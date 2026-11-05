{ lib, config, pkgs, ... }:

let
  cfg = config.modules.features.vaultwarden;
in
{
  options.modules.features.vaultwarden.enable =
    lib.mkEnableOption "Vaultwarden password manager";

  config = lib.mkIf cfg.enable {
    networking.proxyBackendPorts = [ 8222 ];

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
        ROCKET_ADDRESS = config.networking.fleet.r730xd.ip;
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
