{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.features.backup-assurance;

  # Reusable backup rules for different jobs
  backupRules = ''
    groups:
      - name: backup-assurance
        rules:
          - alert: ResticBackupNeverSucceeded
            expr: nixlab_restic_backup_last_success_timestamp_seconds == 0
            for: 30m
            labels:
              severity: critical
            annotations:
              summary: Restic backup has never succeeded
              description: The Restic backup job {{ $labels.job }} has not recorded a successful backup.

          - alert: ResticBackupFailed
            expr: nixlab_restic_backup_last_result == 0 and nixlab_restic_backup_last_success_timestamp_seconds > 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: Restic backup failed
              description: The latest Restic backup for job {{ $labels.job }} failed.

          - alert: ResticVerificationFailed
            expr: nixlab_restic_verify_last_result == 0 and nixlab_restic_verify_last_success_timestamp_seconds > 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: Restic repository verification failed
              description: The latest repository integrity check for Restic job {{ $labels.job }} failed.

          - alert: ResticRestoreTestFailed
            expr: nixlab_restic_restore_test_last_result == 0 and nixlab_restic_restore_test_last_success_timestamp_seconds > 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: Restic restore test failed
              description: The latest isolated restore test for Restic job {{ $labels.job }} failed.
  '';

  # Common staleness rule template
  mkStalenessRule = 
    {
      name,
      metric,
      maxAge,
      severity,
      summary,
      description,
    }:
    ''
      groups:
        - name: backup-assurance
          rules:
            - alert: ${name}
              expr: time() - ${metric} > ${toString maxAge}
              for: 15m
              labels:
                severity: ${severity}
              annotations:
                summary: ${summary}
                description: ${description}
    '';
in
{
  options.modules.features.backup-assurance = {
    enable = lib.mkEnableOption "Restic backup assurance alerting";

    backupMaxAge = lib.mkOption {
      type = lib.types.ints.positive;
      default = 93600;
      description = "Maximum allowed age in seconds for a successful backup.";
    };

    verifyMaxAge = lib.mkOption {
      type = lib.types.ints.positive;
      default = 691200;
      description = "Maximum allowed age in seconds for successful repository verification.";
    };

    restoreTestMaxAge = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3024000;
      description = "Maximum allowed age in seconds for a successful isolated restore test.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.features.restic-backup.enable;
        message = "modules.features.backup-assurance requires modules.features.restic-backup.";
      }
      {
        assertion = config.services.prometheus.exporters.node.enable;
        message = "modules.features.backup-assurance requires the Prometheus node exporter.";
      }
    ];

    services.prometheus.rules = [
      backupRules

      (mkStalenessRule {
        name = "ResticBackupStale";
        metric = "nixlab_restic_backup_last_success_timestamp_seconds";
        maxAge = cfg.backupMaxAge;
        severity = "warning";
        summary = "Restic backup is stale";
        description = "The Restic backup job {{ $labels.job }} has not completed successfully within the configured threshold.";
      })

      (mkStalenessRule {
        name = "ResticVerificationStale";
        metric = "nixlab_restic_verify_last_success_timestamp_seconds";
        maxAge = cfg.verifyMaxAge;
        severity = "warning";
        summary = "Restic repository verification is stale";
        description = "The Restic repository integrity check for job {{ $labels.job }} has not succeeded within the configured threshold.";
      })

      (mkStalenessRule {
        name = "ResticRestoreTestStale";
        metric = "nixlab_restic_restore_test_last_success_timestamp_seconds";
        maxAge = cfg.restoreTestMaxAge;
        severity = "warning";
        summary = "Restic isolated restore test is stale";
        description = "The isolated Restic restore test for job {{ $labels.job }} has not succeeded within the configured threshold.";
      })
    ];
  };
}