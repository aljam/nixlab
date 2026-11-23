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

  severityRoute =
    severity:
    lib.findSingle (
      route: lib.elem "severity=\"${severity}\"" route.matchers
    ) null null alertConfig.route.routes;

  check = condition: message: if condition then true else throw message;

  severityChecks = map (
    severity: check (severityRoute severity != null) "Alertmanager is missing route for severity: ${severity}"
  ) severities;

  routingPolicyChecks = map (
    severity:
    let
      route = severityRoute severity;
    in
    check (
      route != null && route.repeat_interval != null && route.group_wait != null
    ) "Alertmanager severity route for ${severity} is missing notification policy"
  ) severities;

  tailscaleRulesFile = ../modules/features/prometheus/rules/tailscale-rules.yml;

  tailscaleAlerts = [
    {
      name = "TailscaleStatusDown";
      severity = "critical";
    }
    {
      name = "TailscaleDegraded";
      severity = "warning";
    }
    {
      name = "TailscaleServiceUnreachable";
      severity = "critical";
    }
    {
      name = "TailscaleProbeMissing";
      severity = "warning";
    }
  ];

  tailscaleAlertChecks = map (
    alert: check (lib.elem alert.severity severities) "Tailscale alert ${alert.name} uses an unroutable severity: ${alert.severity}"
  ) tailscaleAlerts;

  checks = [
    (check (alertHosts != { }) "No host enables Alertmanager; cannot validate alert routing.")
  ]
  ++ map (
    receiver: check (lib.elem receiver receiverNames) "Alertmanager is missing receiver: ${receiver}"
  ) expectedReceivers
  ++ severityChecks
  ++ routingPolicyChecks
  ++ tailscaleAlertChecks;
in
pkgs.runCommand "alert-routing-check"
  {
    inherit tailscaleRulesFile;
  }
  ''
    for alert in TailscaleStatusDown TailscaleDegraded TailscaleServiceUnreachable TailscaleProbeMissing; do
      grep -q "alert: ''${alert}" "$tailscaleRulesFile" || {
        echo "Missing Tailscale alert: ''${alert}" >&2
        exit 1
      }
    done

    touch $out
  ''
