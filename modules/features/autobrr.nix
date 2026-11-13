{
  config,
  pkgs,
  domains,
  fleet,
  subnets,
  ...
}:
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

  assertions = [
    # Autobrr should use the host's service address rather than every interface.
    {
      assertion =
        !(config.services.autobrr.enable or false) || config.services.autobrr.settings.host != "0.0.0.0";
      message = "Autobrr must bind to the host service address, not all interfaces.";
    }
  ];
}
