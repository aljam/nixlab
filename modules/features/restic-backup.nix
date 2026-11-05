{ lib, config, pkgs, ... }:

let
  cfg = config.modules.features.restic-backup;
  backupUser = "restic-backup";
  backupGroup = "restic-backup";
  repository = cfg.repository;
  passwordFile = config.sops.secrets.restic-backup-password.path;
  postgresDumpDir = "/var/lib/restic-backup/postgresql";

  postgresDumpScript = pkgs.writeShellApplication {
    name = "postgresql-restic-dump";
    runtimeInputs = with pkgs; [ postgresql restic ];
    text = ''
      set -euo pipefail

      install -d -m 0700 -o ${backupUser} -g ${backupGroup} ${postgresDumpDir}

      for database in webscraper admin matrix-synapse; do
        dump="${postgresDumpDir}/''${database}.dump"
        temporary="''${dump}.tmp"

        runuser -u postgres -- pg_dump --dbname="$database" --format=custom --file="$temporary"
        chown ${backupUser}:${backupGroup} "$temporary"
        chmod 0600 "$temporary"
        mv "$temporary" "$dump"
      done

      restic backup \
        --repo "${repository}" \
        --password-file "${passwordFile}" \
        "${postgresDumpDir}"

      restic forget \
        --repo "${repository}" \
        --password-file "${passwordFile}" \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6 \
        --prune
    '';
  };
in
{
  options.modules.features.restic-backup = {
    enable = lib.mkEnableOption "local Restic backups";

    repository = lib.mkOption {
      type = lib.types.str;
      description = ''
        Local Restic repository location. This must be a dedicated backup
        dataset or directory; it must not be a subdirectory of a dataset that
        is itself included in the backup.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${backupGroup} = { };

    users.users.${backupUser} = {
      isSystemUser = true;
      group = backupGroup;
      home = "/var/lib/${backupUser}";
      createHome = true;
    };

    sops.secrets.restic-backup-password = {
      sopsFile = ../../secrets/backups.yaml;
      owner = backupUser;
      group = backupGroup;
      mode = "0400";
    };

    systemd.services.restic-postgresql-backup = {
      description = "Nightly PostgreSQL Restic backup";
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${postgresDumpScript}/bin/postgresql-restic-dump";
        PrivateTmp = true;
      };
    };

    systemd.timers.restic-postgresql-backup = {
      description = "Run nightly PostgreSQL Restic backup";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "*-*-* 03:30:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };
  };
}
