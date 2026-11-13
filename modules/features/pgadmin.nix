{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.pgadmin;
in
{
  options.modules.features.pgadmin.enable =
    lib.mkEnableOption "loopback-only pgAdmin database administration";

  config = lib.mkIf cfg.enable {
    sops.secrets."pgadmin_password" = {
      sopsFile = ../../secrets/database.yaml;
      owner = "pgadmin";
      group = "pgadmin";
      mode = "0400";
      restartUnits = [ "pgadmin.service" ];
    };

    users.groups.pgadmin = { };

    users.users.pgadmin = {
      isSystemUser = true;
      group = "pgadmin";
    };

    services.pgadmin = {
      enable = true;

      # pgAdmin is administrative tooling and must remain reachable only from
      # the host itself. It is intentionally excluded from the HAProxy backend
      # allowlist and the public Homepage dashboard.
      listenAddress = "127.0.0.1";
      port = 5050;

      initialEmail = "aljam@${config.networking.myDomain}";
      initialPasswordFile = config.sops.secrets."pgadmin_password".path;
    };

    systemd.services.pgadmin = {
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
        ReadWritePaths = [ "/var/lib/pgadmin" ];
      };
    };

    assertions = [
      {
        assertion = !(lib.elem 5050 config.networking.proxyBackendPorts);
        message = "pgAdmin must remain loopback-only and must not be exposed through the HAProxy backend allowlist.";
      }
    ];
  };
}
