{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.restic-backup;
  backupUser = "restic-backup";
  backupGroup = "restic-backup";
  passwordFile = config.sops.secrets.restic-backup-password.path;
  lockFile = "/run/restic-backup.lock";
  metricsDirectory = "/var/lib/node-exporter/textfile";

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

      runtimePackages = lib.mkOption {
        type = with lib.types; listOf package;
        default = [ ];
        description = "Additional packages required by this job pre-backup script. Keep this limited to the tools that job actually needs.";
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

  backupScript =
    name: job:
    let
      resticCommonArgs =
        "--repo ${lib.escapeShellArg job.repository} "
        + "--password-file ${lib.escapeShellArg passwordFile}";

      metricFile = "${metricsDirectory}/restic-backup-${name}.prom";

      initCommand =
        if lib.hasPrefix "/" job.repository then
          ''
            if [[ ! -f ${lib.escapeShellArg job.repository}/config ]]; then
              runuser -u ${backupUser} -- restic init \\
                ${resticCommonArgs}
            fi
          ''
        else
          "";
    in
    pkgs.writeShellApplication {
      name = "restic-backup-${name}";
      runtimeInputs = [
        pkgs.restic
        pkgs.util-linux
      ]
      ++ job.runtimePackages;
      text = ''
        set -euo pipefail

        install -d -o node-exporter -g node-exporter -m 0750 \\
          ${lib.escapeShellArg metricsDirectory}

        metric_file=${lib.escapeShellArg metricFile}
        metric_tmp="${metricFile}.tmp"

        if [[ ! -s "$metric_file" ]]; then
          cat > "$metric_tmp" <<EOF
        # HELP nixlab_restic_backup_last_success_timestamp_seconds Unix time of the last successful Restic backup.
        # TYPE nixlab_restic_backup_last_success_timestamp_seconds gauge
        nixlab_restic_backup_last_success_timestamp_seconds{job="${name}"} 0
        EOF
          install -o node-exporter -g node-exporter -m 0644 \\
            "$metric_tmp" "$metric_file"
          rm -f "$metric_tmp"
        fi

        exec 9>${lib.escapeShellArg lockFile}
        flock 9

        ${initCommand}

        ${job.preBackupScript}

        restic backup \\
          ${resticCommonArgs} \\
          ${lib.concatMapStringsSep " \\\\\n          " (path: lib.escapeShellArg path) job.paths}

        restic forget \\
          ${resticCommonArgs} \\
          --keep-daily ${toString job.retention.keepDaily} \\
          --keep-weekly ${toString job.retention.keepWeekly} \\
          --keep-monthly ${toString job.retention.keepMonthly} \\
          --prune

        cat > "$metric_tmp" <<EOF
        # HELP nixlab_restic_backup_last_success_timestamp_seconds Unix time of the last successful Restic backup.
        # TYPE nixlab_restic_backup_last_success_timestamp_seconds gauge
        nixlab_restic_backup_last_success_timestamp_seconds{job="${name}"} $(date +%s)
        EOF
        install -o node-exporter -g node-exporter -m 0644 \\
          "$metric_tmp" "$metric_file"
        rm -f "$metric_tmp"
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

    systemd.tmpfiles.rules = [
      "d /var/lib/restic-backup 0711 restic-backup restic-backup - -"
      "d /var/lib/restic-backup/postgresql 0730 postgres restic-backup - -"
      "d /var/lib/restic-backup/repo 0700 restic-backup restic-backup - -"
    ];

    systemd.services = lib.mapAttrs' (
      name: job:
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
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
        };
      }
    ) cfg.jobs;

    systemd.timers = lib.mapAttrs' (
      name: job:
      lib.nameValuePair "restic-backup-${name}" {
        description = "Run Restic backup: ${name}";
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnCalendar = job.schedule;
          Persistent = true;
          RandomizedDelaySec = job.randomizedDelay;
        };
      }
    ) cfg.jobs;
  };
}
