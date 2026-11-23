{
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;

  alertHosts = lib.filterAttrs (_: value: value.config.services.prometheus.alertmanager.enable) hosts;

  alertHost = builtins.head (builtins.attrNames alertHosts);

  alertConfig = hosts.${alertHost}.config.services.prometheus.alertmanager.configuration;

  receiverNames = map (receiver: receiver.name) alertConfig.receivers;

  expectedReceivers = [
    "ntfy-default"
    "ntfy-critical"
    "ntfy-warning"
    "ntfy-info"
  ];

  severities = [
    "critical"
    "warning"
    "info"
  ];

  hasRoute =
    severity:
    lib.any (route: lib.elem "severity=\"${severity}\"" route.matchers) alertConfig.route.routes;

  check = condition: message: if condition then true else throw message;

  severityChecks = map (
    severity: check (hasRoute severity) "Alertmanager is missing route for severity: ${severity}"
  ) severities;

  checks = [
    (check (alertHosts != { }) "No host enables Alertmanager; cannot validate alert routing.")
  ]
  ++ map (
    receiver: check (lib.elem receiver receiverNames) "Alertmanager is missing receiver: ${receiver}"
  ) expectedReceivers
  ++ severityChecks;
in
pkgs.runCommand "alert-routing-check" { } ''
  touch $out
''
