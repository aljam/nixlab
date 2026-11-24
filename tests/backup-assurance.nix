{
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;

  assuranceHosts = lib.filterAttrs (
    _: value:
    lib.attrByPath [
      "config"
      "modules"
      "features"
      "backup-assurance"
      "enable"
    ] false value
  ) hosts;

  expectedHosts = [
    "navi"
    "oryx"
  ];

  check = condition: message: if condition then true else throw message;

  prerequisiteChecks = lib.mapAttrsToList (
    hostname: host:
    check (
      host.config.modules.features.restic-backup.enable
      && host.config.modules.features.node-exporter.enable
    ) "${hostname} enables backup-assurance without restic-backup and node-exporter."
  ) assuranceHosts;

  hostChecks = map (
    hostname:
    check (lib.elem hostname (builtins.attrNames assuranceHosts)) "Expected host ${hostname} does not enable backup-assurance."
  ) expectedHosts;

  dashboardFile = ../modules/features/grafana/assets/backup-assurance.json;
  dashboard = builtins.fromJSON (builtins.readFile dashboardFile);

  expectedAlerts = [
    "ResticBackupNeverSucceeded"
    "ResticBackupFailed"
    "ResticBackupStale"
    "ResticVerificationFailed"
    "ResticVerificationStale"
    "ResticRestoreTestFailed"
    "ResticRestoreTestStale"
  ];

  expectedMetrics = [
    "nixlab_restic_backup_last_result"
    "nixlab_restic_backup_last_success_timestamp_seconds"
    "nixlab_restic_verify_last_result"
    "nixlab_restic_verify_last_success_timestamp_seconds"
    "nixlab_restic_restore_test_last_result"
    "nixlab_restic_restore_test_last_success_timestamp_seconds"
  ];

  alertChecks = map (
    alert: check (lib.elem alert expectedAlerts) "Backup-assurance rules are missing alert: ${alert}"
  ) expectedAlerts;

  metricChecks = map (
    metric:
    check (lib.elem metric expectedMetrics) "Backup-assurance dashboard is missing metric: ${metric}"
  ) expectedMetrics;

  checks = [
    (check (assuranceHosts != { }) "No host enables backup-assurance.")
    (check (dashboard.uid == "backup-assurance") "Grafana dashboard has an unexpected UID.")
    (check (dashboard.title == "Backup Assurance") "Grafana dashboard has an unexpected title.")
  ]
  ++ hostChecks
  ++ prerequisiteChecks
  ++ alertChecks
  ++ metricChecks;
in
pkgs.runCommand "backup-assurance-config-check"
  {
    inherit dashboardFile;
  }
  ''
    ${pkgs.jq}/bin/jq -e '.uid == "backup-assurance" and .title == "Backup Assurance"' "$dashboardFile" >/dev/null

    for metric in nixlab_restic_backup_last_result nixlab_restic_backup_last_success_timestamp_seconds nixlab_restic_verify_last_result nixlab_restic_verify_last_success_timestamp_seconds nixlab_restic_restore_test_last_result nixlab_restic_restore_test_last_success_timestamp_seconds; do
      grep -q "$metric" "$dashboardFile" || {
        echo "Dashboard is missing metric: $metric" >&2
        exit 1
      }
    done

    touch $out
  ''
