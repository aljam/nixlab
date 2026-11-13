{ config, lib, ... }:

let
  backendPorts = config.networking.proxyBackendPorts;

  nodeExporter = config.services.prometheus.exporters.node;
  smartctlExporter = config.services.prometheus.exporters.smartctl;
  prometheusIP = config.networking.fleet.${config.networking.monitoringServer}.ip;

  haproxyRule = lib.concatMapStrings (port: ''
    ip saddr ${config.networking.fleet.proxy.ip} tcp dport ${toString port} accept comment "HAProxy backend"
  '') backendPorts;

  prometheusRule = lib.optionalString (nodeExporter.enable && prometheusIP != null) ''
    ip saddr ${prometheusIP} tcp dport ${toString nodeExporter.port} accept comment "Prometheus node exporter scrape"
  '';

  smartctlRule = lib.optionalString (smartctlExporter.enable && prometheusIP != null) ''
    ip saddr ${prometheusIP} tcp dport ${toString smartctlExporter.port} accept comment "Prometheus smartctl exporter scrape"
  '';
in
{
  networking.firewall.extraInputRules = lib.concatStrings [
    haproxyRule
    prometheusRule
    smartctlRule
  ];

  # The allowlist itself (forbidden ports, duplicates, bind address) is
  # validated in ./security-policy.nix.
}
