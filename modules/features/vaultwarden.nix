# Security: Vaultwarden should NOT be exposed to LAN
# Only accessible via HAProxy gateway (192.168.1.1)
{ config, lib, pkgs, ... }:

{
  networking.proxyBackendPorts = [ 8222 ];

  sops.secrets."vaultwarden-admin-token" = {
    sopsFile = ../../secrets/vaultwarden.yaml;
    mode = "0400";
    owner = "vaultwarden";
  };

  services.vaultwarden = {
    enable = true;
    config = {
      rocketAddress = config.networking.servicesBindAddress;
      rocketPort = 8222;
      domain = "https://vault.${config.networking.myDomain}";
      signupsAllowed = false;
      adminTokenFile = config.sops.secrets."vaultwarden-admin-token".path;
      adminRateLimitSeconds = 300;
      adminRateLimitMaxBurst = 10;
    };
  };
}
