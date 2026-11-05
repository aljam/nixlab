{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.modules.features.postgres;
in {
  imports = [
    ./restic-backup.nix
  ];

  options.modules.features.postgres = {
    enable = lib.mkEnableOption "PostgreSQL server with encrypted LAN access";

    allowedClients = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          database = lib.mkOption {
            type = lib.types.str;
            example = "matrix-synapse";
          };

          user = lib.mkOption {
            type = lib.types.str;
            example = "matrix-synapse";
          };

          address = lib.mkOption {
            type = lib.types.str;
            example = "192.168.1.10/32";
          };
        };
      });
      default = [];
      description = "LAN clients allowed to connect over TLS.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;

      listenAddresses = "0.0.0.0";

      settings = {
        port = 5432;
        ssl = true;
        ssl_cert_file = "/var/lib/postgresql/tls/server.crt";
        ssl_key_file = "/var/lib/postgresql/tls/server.key";
      };

      authentication = lib.concatMapStringsSep "\n" (
        client:
        "hostssl ${client.database} ${client.user} ${client.address} scram-sha-256"
      ) cfg.allowedClients;
    };

    systemd.services.postgresql-tls-cert = {
      description = "Generate self-signed PostgreSQL TLS certificate";
      before = ["postgresql.service"];
      requiredBy = ["postgresql.service"];
      serviceConfig = {
        Type = "oneshot";
        UMask = "0077";
      };
      script = ''
        certDir=/var/lib/postgresql/tls
        install -d -m 0700 -o postgres -g postgres "$certDir"

        if [ ! -s "$certDir/server.key" ] || [ ! -s "$certDir/server.crt" ]; then
          ${pkgs.openssl}/bin/openssl req -new -x509 -days 3650 -nodes \
            -subj "/CN=r820.lan" \
            -keyout "$certDir/server.key" \
            -out "$certDir/server.crt"
          chown postgres:postgres "$certDir/server.key" "$certDir/server.crt"
          chmod 0600 "$certDir/server.key"
          chmod 0644 "$certDir/server.crt"
        fi
      '';
    };

    networking.firewall.extraInputRules = lib.concatMapStringsSep "\n" (
      client: "ip saddr ${client.address} tcp dport 5432 accept"
    ) cfg.allowedClients;

    environment.systemPackages = with pkgs; [
      restic
    ];

    modules.features.restic-backup = {
      enable = true;

      jobs.postgresql = {
        repository = "/var/lib/restic-backup/repo";
        paths = ["/var/lib/restic-backup/postgresql"];
        requires = ["postgresql.service"];
        after = ["postgresql.service"];

        preBackupScript = ''
          backupRoot=/var/lib/restic-backup
          postgresDumpDir="$backupRoot/postgresql"

          install -d -m 0711 "$backupRoot"
          chown restic-backup:restic-backup "$backupRoot"
          chmod 0711 "$backupRoot"

          install -d -m 0730 "$postgresDumpDir"
          chown postgres:restic-backup "$postgresDumpDir"
          chmod 0730 "$postgresDumpDir"

          for database in webscraper admin matrix-synapse; do
            dump="$postgresDumpDir/''${database}.dump"
            temporary="''${dump}.tmp"

            runuser -u postgres -- pg_dump --dbname="$database" --format=custom --file="$temporary"
            chown restic-backup:restic-backup "$temporary"
            chmod 0600 "$temporary"
            mv "$temporary" "$dump"
          done
        '';
      };
    };
  };
}
