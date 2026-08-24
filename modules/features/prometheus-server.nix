# DRY: Use shared proxy IP from flake.nix
{ config, lib, pkgs, ... }:

{
  networking.proxyBackendPorts = [ 9090 ];

  services.prometheus = {
    enable = true;
    port = 9090;
    # Bind to localhost - reverse proxy provides external access
    listenAddress = config.networking.servicesBindAddress;
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [{ targets = ["localhost:9090"]; }];
      }
      {
        job_name = "node";
        static_configs = [{ targets = ["localhost:9100"]; }];
      }
    ];
  };

  # Firewall: Handled centrally by reverse-proxy-backends.nix
}
