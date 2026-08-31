# Central firewall rules for the services that sit behind the HAProxy gateway.
#
# Every rule here MUST be a single line ending in a verdict. nftables accepts a
# rule with no verdict (it matches and falls through), so a rule split across
# two lines does not fail loudly: the match half silently becomes a no-op and
# the verdict half becomes an unconditional `accept` in the input-allow chain,
# which lets in every new inbound connection on every port.
{ config, lib, ... }:

let
  backendPorts = config.networking.proxyBackendPorts;
  proxyIP = config.networking.fleet.proxy.ip;
  prometheusIP = config.networking.fleet.r730xd.ip;
  nodeExporter = config.services.prometheus.exporters.node;

  # The HAProxy gateway is the only client allowed to reach service backends.
  haproxyRule = lib.optionalString (backendPorts != [ ]) ''
    ip saddr ${proxyIP} tcp dport { ${lib.concatMapStringsSep ", " toString backendPorts} } accept comment "HAProxy backend access"
  '';

  # Only the Prometheus server may scrape node_exporter, and only on hosts that
  # actually run it.
  prometheusRule = lib.optionalString nodeExporter.enable ''
    ip saddr ${prometheusIP} tcp dport ${toString nodeExporter.port} accept comment "Prometheus node exporter scrape"
  '';
in
{
  networking.firewall.extraInputRules = lib.concatStrings [
    haproxyRule
    prometheusRule
  ];
}
