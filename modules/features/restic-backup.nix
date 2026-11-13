# Local Restic backups.
#
# Each job runs as root because it may need to read protected application data
# and create consistent dumps. It writes only to its dedicated state tree, lock
# file, and node-exporter metrics directory.
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
  cacheDirectory = "/var/lib/restic-backup/cache";
  metricsDirectory = config.modules.features.node-exporter.textfileDirectory;

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

      prune = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to prune removed snapshots after applying retention.
          Pruning can be expensive; disabling it lets `restic forget` mark
          snapshots for later removal without rewriting repository data on
          every backup.
        '';
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

      verifySchedule = lib.mkOption {
        type = lib.types.str;
        default = "Sun *-*-* 04:30:00";
        description = "systemd timer calendar specification for repository integrity verification.";
      };

      verifyRandomizedDelay = lib.mkOption {
        type = lib.types.str;
        default = "30m";
        description = "Random delay added to the scheduled repository verification start.";
      };

      verifyDataSubset = lib.mkOption {
        type = lib.types.str;
        default = "10%";
        description = "Fraction of repository data read by each integrity verification run.";
      };

      restoreSchedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-01 05:30:00";
        description = "systemd timer calendar specification for the isolated restore test.";
      };

      restoreRandomizedDelay = lib.mkOption {
        type = lib.types.str;
        default = "30m";
        description = "Random delay added to the scheduled restore-test start.";
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

  resticCommonArgs =
    job:
    "--repo ${lib.escapeShellArg job.repository} "
    + "--password-file ${lib.escapeShellArg passwordFile}";

  backupScript =
    name: job:
    let
      commonArgs = resticCommonArgs job;
      metricFile = "${metricsDirectory}/restic-backup-${name}.prom";

      initCommand =
        if lib.hasPrefix "/" job.repository then
          ''
            if [[ ! -f ${lib.escapeShellArg job.repository}/config ]]; then
              runuser -u ${backupUser} -- restic init \
                ${commonArgs}
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

        metric_file=${lib.escapeShellArg metricFile}
        metric_tmp="${metricFile}.tmp"

        if [[ ! -s "$metric_file" ]]; then
          cat > "$metric_tmp" <<EOF
        # HELP nixlab_restic_backup_last_success_timestamp_seconds Unix time of the last successful Restic backup.
        # TYPE nixlab_restic_backup_last_success_timestamp_seconds gauge
        nixlab_restic_backup_last_success_timestamp_seconds{job="${name}"} 0
        EOF
          install -o node-exporter -g node-exporter -m 0644 \
            "$metric_tmp" "$metric_file"
          rm -f "$metric_tmp"
        fi

        exec 9>${lib.escapeShellArg lockFile}
        flock 9

        ${initCommand}

        ${job.preBackupScript}

        restic backup \
          ${commonArgs} \
          ${lib.concatMapStringsSep " \\
          " (path: lib.escapeShellArg path) job.paths}

        restic forget \
          ${commonArgs} \
          --keep-daily ${toString job.retention.keepDaily} \
          --keep-weekly ${toString job.retention.keepWeekly} \
          --keep-monthly ${toString job.retention.keepMonthly}${lib.optionalString job.prune " --prune"}

        cat > "$metric_tmp" <<EOF
        # HELP nixlab_restic_backup_last_success_timestamp_seconds Unix time of the last successful Restic backup.
        # TYPE nixlab_restic_backup_last_success_timestamp_seconds gauge
        nixlab_restic_backup_last_success_timestamp_seconds{job="${name}"} $(date +%s)
        EOF
        install -o node-exporter -g node-exporter -m 0644 \
          "$metric_tmp" "$metric_file"
        rm -f "$metric_tmp"
      '';
    };

  verifyScript =
    name: job:
    let
      commonArgs = resticCommonArgs job;
      metricFile = "${metricsDirectory}/restic-verify-${name}.prom";
    in
    pkgs.writeShellApplication {
      name = "restic-verify-${name}";
      runtimeInputs = [
        pkgs.restic
        pkgs.util-linux
        pkgs.coreutils
      ];
      text = ''
        set -euo pipefail

        metric_file=${lib.escapeShellArg metricFile}
        metric_tmp="${metricFile}.tmp"

        exec 9>${lib.escapeShellArg lockFile}
        flock 9

        restic check \
          ${commonArgs} \
          --read-data-subset=${lib.escapeShellArg job.verifyDataSubset}

        cat > "$metric_tmp" <<EOF
        # HELP nixlab_restic_verify_last_success_timestamp_seconds Unix time of the last successful Restic repository integrity verification.
        # TYPE nixlab_restic_verify_last_success_timestamp_seconds gauge
        nixlab_restic_verify_last_success_timestamp_seconds{job="${name}"} $(date +%s)
        EOF
        install -o node-exporter -g node-exporter -m 0644 \
          "$metric_tmp" "$metric_file"
        rm -f "$metric_tmp"
      '';
    };

  restoreTestScript =
    name: job:
    let
      commonArgs = resticCommonArgs job;
      metricFile = "${metricsDirectory}/restic-restore-test-${name}.prom";

      pathChecks = lib.concatMapStringsSep "\n" (
        path:
        ''
          if [[ ! -e "$restore_dir/${lib.escapeShellArg (lib.removePrefix "/" path)}" ]]; then
            echo "restic-restore-test-${name}: expected restored path missing: ${lib.escapeShellArg path}" >&2
            exit 1
          fi
        ''
      ) job.paths;
    in
    pkgs.writeShellApplication {
      name = "restic-restore-test-${name}";
      runtimeInputs = [
        pkgs.restic
        pkgs.util-linux
        pkgs.coreutils
      ];
      text = ''
        set -euo pipefail

        metric_file=${lib.escapeShellArg metricFile}
        metric_tmp="${metricFile}.tmp"

        exec 9>${lib.escapeShellArg lockFile}
        flock 9

        restore_dir="$(mktemp -d "${lib.escapeShellArg cacheDirectory}/restore-test-${name}.XXXXXX")"
        cleanup() {
          rm -rf -- "$restore_dir"
        }
        trap cleanup EXIT

        restic restore latest \
          ${commonArgs} \
          --target "$restore_dir"

        ${pathChecks}

        cat > "$metric_tmp" <<EOF
        # HELP nixlab_restic_restore_test_last_success_timestamp_seconds Unix time of the last successful isolated Restic restore test.
        # TYPE nixlab_restic_restore_test_last_success_timestamp_seconds gauge
        nixlab_restic_restore_test_last_success_timestamp_seconds{job="${name}"} $(date +%s)
        EOF
        install -o node-exporter -g node-exporter -m 0644 \
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
      "d /var/lib/restic-backup/cache 0700 restic-backup restic-backup - -"
      "d /var/lib/restic-backup/postgresql 0730 postgres restic-backup - -"
      "d /var/lib/restic-backup/repo 0700 restic-backup restic-backup - -"
      # The units list the lock in ReadWritePaths, and systemd refuses to start
      # a unit whose ReadWritePaths entry is missing. /run is empty after a
      # reboot, so the lock must exist before the first job runs.
      "f ${lockFile} 0600 root root - -"
    ];

    systemd.services = lib.mkMerge (
      lib.mapAttrsToList (name: job: {
        "restic-backup-${name}" = {
          description = "Restic backup: ${name}";
          requires = job.requires;
          after = [ "sops-nix.service" ] ++ job.after;
          # Deliberately no `wantedBy`: the timer below is the only trigger.
          # A oneshot unit wanted by multi-user.target reruns on every boot and
          # on every `nixos-rebuild switch`.

          environment = {
            RESTIC_CACHE_DIR = cacheDirectory;
          };

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = lib.getExe (backupScript name job);
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [
              "/var/lib/restic-backup"
              "/run/restic-backup.lock"
              metricsDirectory
            ];
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
          };
        };

        "restic-verify-${name}" = {
          description = "Verify Restic repository integrity: ${name}";
          requires = job.requires;
          after = [ "sops-nix.service" ] ++ job.after;

          environment = {
            RESTIC_CACHE_DIR = cacheDirectory;
          };

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = lib.getExe (verifyScript name job);
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [
              "/var/lib/restic-backup"
              "/run/restic-backup.lock"
              metricsDirectory
            ];
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
          };
        };

        "restic-restore-test-${name}" = {
          description = "Validate Restic restore readiness: ${name}";
          requires = job.requires;
          after = [ "sops-nix.service" ] ++ job.after;

          environment = {
            RESTIC_CACHE_DIR = cacheDirectory;
          };

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = lib.getExe (restoreTestScript name job);
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [
              "/var/lib/restic-backup"
              "/run/restic-backup.lock"
              metricsDirectory
            ];
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
          };
        };
      }) cfg.jobs
    );

    systemd.timers = lib.mkMerge (
      lib.mapAttrsToList (name: job: {
        "restic-backup-${name}" = {
          description = "Run Restic backup: ${name}";
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = job.schedule;
            Persistent = true;
            RandomizedDelaySec = job.randomizedDelay;
          };
        };

        "restic-verify-${name}" = {
          description = "Verify Restic repository integrity: ${name}";
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = job.verifySchedule;
            Persistent = true;
            RandomizedDelaySec = job.verifyRandomizedDelay;
          };
        };

        "restic-restore-test-${name}" = {
          description = "Validate Restic restore readiness: ${name}";
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = job.restoreSchedule;
            Persistent = true;
            RandomizedDelaySec = job.restoreRandomizedDelay;
          };
        };
      }) cfg.jobs
    );
  };
}
