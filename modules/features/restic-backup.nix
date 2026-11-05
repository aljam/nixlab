{ lib, config, pkgs, ... }:

let
  cfg = config.modules.features.restic-backup;
  backupUser = "restic-backup";
  backupGroup = "restic-backup";
  passwordFile = config.sops.secrets.restic-backup-password.path;

  jobModule = {
    options = {
      repository = lib.mkOption {
        type = lib.types.str;
        description = "Restic repository used by this backup job.";
      };

      paths = lib.mkOption {
        type = with lib.types; nonEmptyListOf str;
        description = "Filesystem paths included in this backup job.";
      };

      preBackupScript = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Commands run before `restic backup`. Use this to create consistent application dumps.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:30:00";
        description = "systemd timer calendar specification.";
      };

      randomizedDelay = lib.mkOption {
        type = lib.types.str;
        default = "15m";
        description = "Random delay added to the scheduled backup start.";
      };

      requires = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = "Systemd units required by this backup job.";
      };

      after = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = "Systemd units this backup job starts after.";
      };

      retention = {
        keepDaily = lib.mkOption {
          type = lib.types.ints.positive;
          default = 7;
        };

        keepWeekly = lib.mkOption {
          type = lib.types.ints.positive;
          default = 4;
        };

        keepMonthly = lib.mkOption {
          type = lib.types.ints.positive;
          default = 6;
        };
      };
    };
  };

  backupScript = name: job:
    pkgs.writeShellApplication {
      name = "restic-backup-${name}";
      runtimeInputs = with pkgs; [ restic util-linux postgresql ];
      text = ''
        set -euo pipefail

        ${job.preBackupScript}

        restic backup \
          --repo ${lib.escapeShellArg job.repository} \
          --password-file ${lib.escapeShellArg passwordFile} \
          ${lib.concatMapStringsSep " \\\n          " (path: lib.escapeShellArg path) job.paths}

        restic forget \
          --repo ${lib.escapeShellArg job.repository} \
          --password-file ${lib.escapeShellArg passwordFile} \
          --keep-daily ${toString job.retention.keepDaily} \
          --keep-weekly ${toString job.retention.keepWeekly} \
          --keep-monthly ${toString job.retention.keepMonthly} \
          --prune
      '';
    };
in
{
  options.modules.features.restic-backup = {
    enable = lib.mkEnableOption "local Restic backups";

    jobs = lib.mkOption {
      type = with lib.types; attrsOf (submodule jobModule);
      default = { };
      description = "Named local Restic backup jobs.";
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

    systemd.services = lib.mapAttrs' (name: job:
      lib.nameValuePair "restic-backup-${name}" {
        description = "Restic backup: ${name}";
        requires = job.requires;
        after = [ "sops-nix.service" ] ++ job.after;
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = lib.getExe (backupScript name job);
          PrivateTmp = true;
        };
      }) cfg.jobs;

    systemd.timers = lib.mapAttrs' (name: job:
      lib.nameValuePair "restic-backup-${name}" {
        description = "Run Restic backup: ${name}";
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnCalendar = job.schedule;
          Persistent = true;
          RandomizedDelaySec = job.randomizedDelay;
        };
      }) cfg.jobs;
  };
}
