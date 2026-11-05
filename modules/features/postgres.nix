{ lib, config, pkgs, ... }:

{
  imports = [ ./restic-backup.nix ];

  modules.features.restic-backup = {
    enable = true;

    jobs.postgresql = {
      repository = "/var/lib/restic-backup/repo";
      paths = [ "/var/lib/restic-backup/postgresql" ];
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];

      preBackupScript = ''
        postgresDumpDir=/var/lib/restic-backup/postgresql
        install -d -m 0700 -o restic-backup -g restic-backup "$postgresDumpDir"

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

  # Exempt from a restart/reload consumer: pgAdmin consumes this password only
  # while provisioning its initial administrator account. Rotating it does not
  # require restarting the running pgAdmin service.
}
