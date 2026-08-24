{ config, lib, pkgs, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = config.networking.servicesBindAddress;
  
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };
  
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:9090" ];
          }
        ];
      }
  
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "${config.networking.fleet.r730.ip}:9100" ];
            labels = { host = "r730"; };
          }
          {
            targets = [ "${config.networking.fleet.r730xd.ip}:9100" ];
            labels = { host = "r730xd"; };
          }
          {
            targets = [ "${config.networking.fleet.r820.ip}:9100" ];
            labels = { host = "r820"; };
          }
        ];
      }
    ];
  };
}
