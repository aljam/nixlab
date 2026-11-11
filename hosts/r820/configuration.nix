{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/roles/server-core.nix
    ../../modules/features/libvirt.nix
    ../../modules/features/postgres.nix
    ../../modules/features/nix-builder.nix
    ../../modules/features/log-agent.nix
    ../../modules/features/nix-cache.nix
    #../../modules/features/mail-server.nix
    #../../modules/roles/mail-node.nix
  ];

  roles.server.enable = true;

  modules.features.postgres = {
    enable = true;

    ensureDatabases = [
      "matrix-synapse"
      "admin"
      "peertube"
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
        name = "peertube";
        ensureDBOwnership = true;
      }
    ];

    allowedClients = [
      {
        database = "matrix-synapse";
        user = "matrix-synapse";
        address = "${config.networking.fleet.r730xd.ip}/32";
      }
      {
        database = "peertube";
        user = "peertube";
        address = "${config.networking.fleet.r730xd.ip}/32";
      }
    ];
  };

  # PeerTube (r730xd) needs these extensions in its database. The role
  # password is managed out-of-band: secrets/peertube.yaml is not encrypted
  # for r820, so it is set once with `ALTER ROLE peertube PASSWORD '…'`.
  systemd.services.postgresql-peertube-extensions = {
    description = "Ensure PeerTube PostgreSQL extensions";
    # ensureDatabases runs in postgresql-setup.service; the database must exist first.
    after = [ "postgresql-setup.service" ];
    requires = [ "postgresql-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };
    path = with pkgs; [
      postgresql
      util-linux
    ];
    script = ''
      runuser -u postgres -- psql \
        --set=ON_ERROR_STOP=1 \
        --username=postgres \
        --dbname=peertube <<'SQL'
        CREATE EXTENSION IF NOT EXISTS pg_trgm;
        CREATE EXTENSION IF NOT EXISTS unaccent;
      SQL
    '';
  };

  # Only members of `users` may connect to the Nix daemon. Nobody besides
  # root is a trusted user: daemon trust is equivalent to root, and remote
  # builds use the dedicated account in modules/features/nix-builder.nix.
  nix.settings.allowed-users = [ "@users" ];

  services.nixlab.logShipping = {
    enable = true;
    lokiUrl = "http://${config.networking.fleet.r730xd.ip}:3100/loki/api/v1/push";
  };
}
