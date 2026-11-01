{ config, pkgs, domains, fleet, subnets, ... }:
{
  networking.proxyBackendPorts = [ 7474 ];

  users.groups.autobrr = { };
  users.users.autobrr = {
    isSystemUser = true;
    group = "autobrr";
  };

  services.autobrr = {
    enable = true;
    openFirewall = false;
    settings.host = config.networking.servicesBindAddress;
  };

  networking.firewall.extraInputRules = ''
    ip saddr ${config.networking.subnets.lan}.1 tcp dport 7474 accept
  '';
}
