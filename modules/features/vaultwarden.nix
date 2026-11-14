{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.vaultwarden;
in
{
  options.modules.features.vaultwarden.enable = lib.mkEnableOption "Vaultwarden password manager";

  config = lib.mkIf cfg.enable {
    networking.proxyBackendPorts = [ 8222 ];

    sops.secrets."vaultwarden-admin-token" = mkSecret {
      name = "vaultwarden-admin-token";
      sopsFile = ../../secrets/vaultwarden.yaml;
      owner = "vaultwarden";
      group = "vaultwarden";
      restartUnits = [ "vaultwarden.service" ];
    };

    services.vaultwarden = {
      enable = true;

      config = {
        ROCKET_ADDRESS = config.networking.servicesBindAddress;
        ROCKET_PORT = "8222";
        SIGNUPS_ALLOWED = "false";
        DOMAIN = "https://vault.${config.networking.myDomain}";
        ADMIN_TOKEN_FILE = config.sops.secrets."vaultwarden-admin-token".path;
        ADMIN_RATELIMIT_SECONDS = "60";
        ADMIN_RATELIMIT_MAX_BURST = "3";
      };
    };

    systemd.services.vaultwarden = {
      serviceConfig = {
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        CapabilityBoundingSet = [ "" ];
        SystemCallArchitectures = "native";
        ReadWritePaths = [ "/var/lib/vaultwarden" ];
      };
    };
  };
}
