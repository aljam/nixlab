# Disabled Restic replication scaffolding.
#
# This module intentionally has no enabled configuration, external endpoint,
# or credentials. It establishes the future `restic copy` workflow and its
# assurance metrics without changing the current local-only backup behavior.
{
  lib,
  config,
  pkgs,
  mkSecret,
  ...
}:

let
  cfg = config.modules.features.restic-replication;
  replicationUser = "restic-replication";
  replicationGroup = "restic-replication";
  passwordFile = config.sops.secrets.restic-replication-password.path;
  lockFile = "/run/restic-replication.lock";
  cacheDirectory = "/var/lib/restic-replication/cache";
  metricsDirectory = config.modules.features.node-exporter.textfileDirectory;

  jobModule = {
    options = {
      sourceRepository = lib.mkOption {
        type = lib.types.str;
        description = "Local Restic repository from which snapshots are copied.";
      };

      destinationRepository = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Destination Restic repository for replicated snapshots.
          This must remain null until an approved off-site destination is configured.
        '';
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 05:30:00";
        description = "systemd timer calendar specification for replication.";
      };

      randomizedDelay = lib.mkOption {
        type = lib.types.str;
        default = "*min";
        description = "Random delay between scheduled replication runs.";
      };

      restoreTestSchedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-01 06:30:00";
        description = "systemd timer calendar specification for the remote restore test.";
      };

      restoreTestRandomizedDelay = lib.mkOption {
        type = lib.types.str;
        default = "*min";
        description = "Random delay between scheduled remote restore-test runs.";
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
    "--repo ${lib.escapeShellArg job.sourceRepository} "
    + "--password-file ${lib.escapeShellArg passwordFile}";

  resultMetricHelpers = name: ''
    write_result_metrics() {
      local result="$1"
      local duration="$2"
      local success_timestamp="$3"

      cat > "$metric_tmp" <<EOF
    # HELP nixlab_restic_replication_last_success_timestamp_seconds Unix time of the last successful Restic replication.
    # TYPE nixlab_restic_replication_last_success_timestamp_seconds gauge
    nixlab_restic_replication_last_success_timestamp_seconds{job="${name}"} "$success_timestamp"

    # HELP nixlab_restic_replication_last_result Result of the latest Restic replication.
    # TYPE nixlab_restic_replication_last_result gauge
    nixlab_restic_replication_last_result{job="${name}"} "$result"

    # HELP nixlab_restic_replication_duration_seconds Duration of the latest Restic replication.
    # TYPE nixlab_restic_replication_duration_seconds gauge
    nixlab_restic_replication_duration_seconds{job="${name}"} "$duration"
    EOF

      install -o node-exporter -g node-exporter -m 0644 \\
        "$metric_tmp" "$metric_file"
      rm -f "$metric_tmp"
    }

    report_failure() {
      write_result_metrics 0 "$(($(date +%s) - start_time))" "$success_timestamp"
      exit 1
    }
  '';

  replicationScript =
    name: job:
    let
      commonArgs = resticCommonArgs job;
      metricFile = "${metricsDirectory}/restic-replication-${name}.prom";
    in
    pkgs.writeShellApplication {
      name = "restic-replication-${name}";
      runtimeInputs = [
        pkgs.restic
        pkgs.util-linux
        pkgs.coreutils
      ];
      text = resultMetricHelpers name + ''
        set -euo pipefail

        metric_file=${lib.escapeShellArg metricFile}
        metric_tmp="${metricFile}.tmp"
        success_timestamp=0
        start_time=$(date +%s)

        if [[ -s "$metric_file" ]]; then
          success_timestamp="$(
            awk '$1 == "nixlab_restic_replication_last_success_timestamp_seconds{job=\"${name}\"}" { print $2; exit }' \\
              "$metric_file"
          )"
        fi

        trap report_failure ERR

        if [[ ! -s "$metric_file" ]]; then
          write_result_metrics 0 0 0
        fi

        exec 9>${lib.escapeShellArg lockFile}
        flock 9

        restic copy \\
          ${commonArgs} \\
          --repo2 ${lib.escapeShellArg job.destinationRepository} \\
          --password-file2 ${lib.escapeShellArg passwordFile}

        restic forget \\
          --repo ${lib.escapeShellArg job.destinationRepository} \\
          --password-file ${lib.escapeShellArg passwordFile} \\
          --keep-daily ${toString job.retention.keepDaily} \\
          --keep-weekly ${toString job.retention.keepWeekly} \\
          --keep-monthly ${toString job.retention.keepMonthly} \\
          --prune

        write_result_metrics 1 "$(($(date +%s) - start_time))" "$(date +%s)"
        trap - ERR
      '';
    };

  remoteRestoreTestScript =
    name: job:
    let
      metricFile = "${metricsDirectory}/restic-replication-restore-test-${name}.prom";
    in
    pkgs.writeShellApplication {
      name = "restic-replication-restore-test-${name}";
      runtimeInputs = [
        pkgs.restic
        pkgs.util-linux
        pkgs.coreutils
      ];
      text = resultMetricHelpers name + ''
        set -euo pipefail

        metric_file=${lib.escapeShellArg metricFile}
        metric_tmp="${metricFile}.tmp"
        success_timestamp=0
        start_time=$(date +%s)

        if [[ -s "$metric_file" ]]; then
          success_timestamp="$(
            awk '$1 == "nixlab_restic_replication_last_success_timestamp_seconds{job=\"${name}\"}" { print $2; exit }' \\
              "$metric_file"
          )"
        fi

        trap report_failure ERR

        if [[ ! -s "$metric_file" ]]; then
          write_result_metrics 0 0 0
        fi

        exec 9>${lib.escapeShellArg lockFile}
        flock 9

        restore_dir="$(mktemp -d "${lib.escapeShellArg cacheDirectory}/restore-test-${name}.XXXXXX")"
        cleanup() {
          rm -rf -- "$restore_dir"
        }
        trap cleanup EXIT

        restic restore latest \\
          --repo ${lib.escapeShellArg job.destinationRepository} \\
          --password-file ${lib.escapeShellArg passwordFile} \\
          --target "$restore_dir"

        write_result_metrics 1 "$(($(date +%s) - start_time))" "$(date +%s)"
        trap - ERR
      '';
    };
in
{
  options.modules.features.restic-replication = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Restic snapshot replication to an approved destination repository.
        This remains disabled until an off-site destination and credentials are configured.
      '';
    };

    jobs = lib.mkOption {
      type = with lib.types; attrsOf (submodule jobModule);
      default = { };
      description = "Named Restic replication jobs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.features.restic-backup.enable;
        message = "modules.features.restic-replication requires modules.features.restic-backup.";
      }
      {
        assertion = config.modules.features.node-exporter.enable;
        message = "modules.features.restic-replication requires the Prometheus node exporter.";
      }
    ]
    ++ lib.mapAttrsToList (
      name: job:
      {
        assertion = job.destinationRepository != null;
        message = "Restic replication job ${name} requires a destinationRepository.";
      }
    ) cfg.jobs;

    roles.security.systemdHardenedServices = lib.concatMap (name: [
      "restic-replication-${name}"
      "restic-replication-restore-test-${name}"
    ]) (lib.attrNames cfg.jobs);

    users.groups.${replicationGroup} = { };

    users.users.${replicationUser} = {
      isSystemUser = true;
      group = replicationGroup;
      home = "/var/lib/${replicationUser}";
      createHome = true;
    };

    sops.secrets.restic-replication-password = mkSecret {
      name = "restic-replication-password";
      sopsFile = ../../secrets/backups.yaml;
      owner = replicationUser;
      group = replicationGroup;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/restic-replication 0711 restic-replication restic-replication - -"
      "d /var/lib/restic-replication/cache 0700 restic-replication restic-replication - -"
      "f ${lockFile} 0600 root root - -"
    ];

    systemd.services = lib.mkMerge (
      lib.mapAttrsToList (name: job: {
        "restic-replication-${name}" = {
          description = "Restic replication: ${name}";
          after = [ "sops-nix.service" ];

          environment = {
            RESTIC_CACHE_DIR = cacheDirectory;
          };

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = lib.getExe (replicationScript name job);
            ReadWritePaths = [
              "/var/lib/restic-replication"
              "/run/restic-replication.lock"
              metricsDirectory
            ];
          };
        };

        "restic-replication-restore-test-${name}" = {
          description = "Validate Restic replication restore readiness: ${name}";
          after = [ "sops-nix.service" ];

          environment = {
            RESTIC_CACHE_DIR = cacheDirectory;
          };

          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = lib.getExe (remoteRestoreTestScript name job);
            ReadWritePaths = [
              "/var/lib/restic-replication"
              "/run/restic-replication.lock"
              metricsDirectory
            ];
          };
        };
      }) cfg.jobs
    );

    systemd.timers = lib.mkMerge (
      lib.mapAttrsToList (name: job: {
        "restic-replication-${name}" = {
          description = "Run Restic replication: ${name}";
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = job.schedule;
            Persistent = true;
            RandomizedDelaySec = job.randomizedDelay;
          };
        };

        "restic-replication-restore-test-${name}" = {
          description = "Validate Restic replication restore readiness: ${name}";
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnCalendar = job.restoreTestSchedule;
            Persistent = true;
            RandomizedDelaySec = job.restoreTestRandomizedDelay;
          };
        };
      }) cfg.jobs
    );
  };
}
