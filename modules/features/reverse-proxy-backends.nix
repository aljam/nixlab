{ config, lib, ... }:

let
  backendPorts = config.networking.proxyBackendPorts;
  prometheusIP = config.networking.fleet.r730xd.ip;

  haproxyRule = lib.optionalString (backendPorts != []) ''
    ip saddr ${config.networking.fleet.proxy.ip} tcp dport {
      ${lib.concatStringsSep ", " (map toString backendPorts)}
    } accept comment "HAProxy backend access"
  '';

  prometheusRule = ''
    ip saddr ${prometheusIP} tcp dport 9100
    accept comment "Prometheus node exporter scrape"
  '';
in
{
  networking.firewall.extraInputRules =
    haproxyRule + prometheusRule;
}
