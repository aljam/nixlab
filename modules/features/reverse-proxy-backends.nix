{ config, lib, ... }:

let
  backendPorts = config.networking.proxyBackendPorts;
in
{
  networking.firewall.extraInputRules =
    (lib.optionalString (backendPorts != []) ''
      ip saddr ${config.networking.fleet.proxy.ip} tcp dport {
        ${lib.concatStringsSep ", " (map toString backendPorts)}
      } accept comment "HAProxy backend access"
    '')
    + ''
      ip saddr ${config.networking.fleet.r730xd.ip}
      tcp dport 9100
      accept comment "Prometheus node exporter scrape"
    '';
}
