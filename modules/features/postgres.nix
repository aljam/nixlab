{ config, pkgs, lib, ... }:

{
  networking.proxyBackendPorts = [ 5050 ];

  sops.secrets.pgadmin_password = {
    owner = "pgadmin";
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;

    settings = {
      listen_addresses = lib.mkForce (lib.concatStringsSep "," [
        "127.0.0.1"
        config.networking.servicesBindAddress
      ]);

      password_encryption = "scram-sha-256";
    };

    authentication = lib.mkOverride 10 ''
      local all all peer
      host all all 127.0.0.1/32 scram-sha-256
      host all all ${config.networking.servicesBindAddress}/32 scram-sha-256
    '';

    ensureDatabases = [ "webscraper" "admin" ];

    ensureUsers = [
      {
        name = "webscraper";
        ensureDBOwnership = true;
      }
      {
        name = "admin";
        ensureDBOwnership = true;
      }
    ];
  };

  services.pgadmin = {
    enable = true;
    initialEmail = "admin@derezzed.info";
    initialPasswordFile = config.sops.secrets.pgadmin_password.path;
    port = 5050;
    settings.DEFAULT_SERVER = config.networking.servicesBindAddress;
  };
}
