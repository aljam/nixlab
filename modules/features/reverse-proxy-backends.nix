{ config, lib, ... }:

let
  backendPorts = config.networking.proxyBackendPorts;

  nodeExporter = config.services.prometheus.exporters.node;
  prometheusIP = config.networking.fleet.${config.networking.monitoringServer}.ip;

  haproxyRule = lib.concatMapStrings (port: ''
    ip saddr ${config.networking.fleet.proxy.ip} tcp dport ${toString port} accept comment "HAProxy backend"
  '') backendPorts;

  prometheusRule = lib.optionalString (nodeExporter.enable && prometheusIP != null) ''
    ip saddr ${prometheusIP} tcp dport ${toString nodeExporter.port} accept comment "Prometheus node exporter scrape"
  '';
in
{
  networking.firewall.extraInputRules = lib.concatStrings [
    haproxyRule
    prometheusRule
  ];

  # The allowlist itself (forbidden ports, duplicates, bind address) is
  # validated in ./security-policy.nix.
}
