{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/roles/server-core.nix
    ../../modules/features/libvirt.nix
    ../../modules/features/postgres.nix
    ../../modules/features/nix-builder.nix
    #../../modules/features/mail-server.nix
    #../../modules/roles/mail-node.nix
  ];

  roles.server.enable = true;

  modules.features.postgres = {
    enable = true;

    ensureDatabases = [
      "matrix-synapse"
      "admin"
      "webscraper"
    ];

    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
      {
        name = "admin";
        ensureDBOwnership = true;
      }
      {
        name = "webscraper";
        ensureDBOwnership = true;
      }
    ];

    allowedClients = [
      {
        database = "matrix-synapse";
        user = "matrix-synapse";
        address = "192.168.1.2/32";
      }
    ];
  };

  # Remote builder configuration
  nix.settings.trusted-users = ["root" "aljam"];
  nix.settings.allowed-users = ["@users"];
}
