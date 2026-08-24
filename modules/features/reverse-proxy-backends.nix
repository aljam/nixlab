{ config, lib, ... }:


let
  backendPorts = config.networking.proxyBackendPorts;
  prometheusScrapeSources = [
    config.networking.fleet.r730.ip
    config.networking.fleet.r730xd.ip
    config.networking.fleet.r820.ip
  ];
in
{
  networking.firewall.extraInputRules =
    (lib.optionalString (backendPorts != []) ''
      ip saddr ${config.networking.fleet.proxy.ip} tcp dport {
        ${lib.concatStringsSep ", " (map toString backendPorts)}
      } accept comment "HAProxy backend access"
    '')
    + ''
      ip saddr ${prometheusScrapeSources}
      tcp dport 9100
      accept comment "Prometheus node exporter scrape"
    '';
}
