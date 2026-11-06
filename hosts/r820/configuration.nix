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

  sops.secrets."peertube-db-password" = {
    sopsFile = ../../secrets/peertube.yaml;
    owner = "postgres";
    group = "postgres";
    mode = "0400";
  };

  modules.features.postgres = {
    enable = true;

    ensureDatabases = ["peertube"];

    ensureUsers = [
      {
        name = "peertube";
        ensureDBOwnership = true;
      }
    ];

    allowedClients = [
      {
        database = "matrix-synapse";
        user = "matrix-synapse";
        address = "192.168.1.2/32";
      }
      {
        database = "peertube";
        user = "peertube";
        address = "192.168.1.2/32";
      }
    ];
  };

  systemd.services.postgresql-peertube-init = {
    description = "Initialize PeerTube PostgreSQL database";
    after = ["postgresql.service" "sops-nix.service"];
    wants = ["postgresql.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };

    script = ''
      until runuser -u postgres -- pg_isready -q; do
        sleep 1
      done

      runuser -u postgres -- psql --dbname=peertube --set=ON_ERROR_STOP=1 <<'SQL'
        CREATE EXTENSION IF NOT EXISTS pg_trgm;
        CREATE EXTENSION IF NOT EXISTS unaccent;
      SQL

      db_password="$(cat "${config.sops.secrets."peertube-db-password".path}")"
      runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --command="ALTER USER peertube WITH PASSWORD '$db_password';"
    '';
  };

  # Remote builder configuration
  nix.settings.trusted-users = ["root" "aljam"];
  nix.settings.allowed-users = ["@users"];
}
