{
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;

  monitoringHosts = lib.filterAttrs (
    _: value:
    lib.attrByPath [
      "config"
      "modules"
      "features"
      "prometheus-server"
    ] null value != null
  ) hosts;

  check = condition: message: if condition then true else throw message;

  scrapeHosts = lib.filterAttrs (
    _: value:
    lib.attrByPath [
      "config"
      "modules"
      "features"
      "prometheus-server"
      "haproxyScrapeTarget"
    ] null value != null
  ) monitoringHosts;

  scrapeChecks = lib.mapAttrsToList (
    hostname: host:
    check (
      !(lib.elem 8404 host.config.networking.proxyBackendPorts)
    ) "${hostname} must not expose the HAProxy metrics port through the HAProxy backend allowlist."
  ) scrapeHosts;

  dashboardFile = ../modules/features/grafana/assets/haproxy.json;
  dashboard = builtins.fromJSON (builtins.readFile dashboardFile);

  expectedAlerts = [
    "HAProxyBackendDown"
    "HAProxyHealthCheckFailed"
    "HAProxyHigh5xxRate"
    "HAProxyConnectionErrors"
    "HAProxyQueueBacklog"
  ];

  expectedMetrics = [
    "haproxy_server_status"
    "haproxy_server_check_status"
    "haproxy_backend_queue_current"
    "haproxy_frontend_http_requests_total"
    "haproxy_frontend_http_responses_total"
    "haproxy_frontend_connection_errors_total"
    "haproxy_backend_http_response_time_average_seconds"
  ];

  rulesFile = ../modules/features/prometheus/rules/haproxy-rules.yml;
  rules = builtins.readFile rulesFile;

  alertChecks = map (
    alert: check (lib.hasInfix alert rules) "HAProxy rules are missing alert: ${alert}"
  ) expectedAlerts;

  metricChecks = map (
    metric:
    check (lib.hasInfix metric (builtins.toJSON dashboard)) "HAProxy dashboard is missing metric: ${metric}"
  ) expectedMetrics;

  checks = [
    (check (dashboard.uid == "haproxy-gateway") "HAProxy dashboard has an unexpected UID.")
    (check (dashboard.title == "HAProxy Gateway") "HAProxy dashboard has an unexpected title.")
  ]
  ++ scrapeChecks
  ++ alertChecks
  ++ metricChecks;
in
pkgs.runCommand "haproxy-observability-config-check"
  {
    inherit dashboardFile rulesFile;
  }
  ''
    ${pkgs.jq}/bin/jq -e '.uid == "haproxy-gateway" and .title == "HAProxy Gateway"' "$dashboardFile" >/dev/null

    for alert in HAProxyBackendDown HAProxyHealthCheckFailed HAProxyHigh5xxRate HAProxyConnectionErrors HAProxyQueueBacklog; do
      grep -q "$alert" "$rulesFile" || {
        echo "HAProxy rules are missing alert: $alert" >&2
        exit 1
      }
    done

    for metric in haproxy_server_status haproxy_server_check_status haproxy_backend_queue_current haproxy_frontend_http_requests_total haproxy_frontend_http_responses_total haproxy_frontend_connection_errors_total haproxy_backend_http_response_time_average_seconds; do
      grep -q "$metric" "$dashboardFile" || {
        echo "HAProxy dashboard is missing metric: $metric" >&2
        exit 1
      }
    done

    touch $out
  ''
