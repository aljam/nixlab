# Security: Vaultwarden should NOT be exposed to LAN
# Only accessible via HAProxy gateway (192.168.1.1)
{ config, lib, pkgs, ... }:

{
  networking.proxyBackendPorts = [ 8222 ];

  # Vaultwarden secrets
  sops.secrets."vaultwarden-admin-token" = {};
  sops.secrets."vaultwarden-admin-token".mode = "0640";
  sops.secrets."vaultwarden-admin-token".owner = "vaultwarden";

  services.vaultwarden = {
    enable = true;
    config = {
      rocketAddress = config.networking.servicesBindAddress;
      rocketPort = 8222;
      domain = "https://vault.${config.networking.domain}";
      signupsAllowed = false;
      adminTokenFile = config.sops.secrets."vaultwarden-admin-token".path;
      adminRateLimitSeconds = 300;
      adminRateLimitMaxBurst = 10;
    };
  };
}
