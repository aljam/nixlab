# Security: Torrent service should NOT be exposed to LAN
# Only accessible via HAProxy gateway (192.168.1.1)
{ config, lib, pkgs, ... }:

{
  networking.proxyBackendPorts = [ 8080 ];

  # qBittorrent service
  services.qbittorrent = {
    enable = true;
    webuiPort = 8080;
  };

  # BitTorrent port for clients
  networking.firewall.allowedTCPPorts = [ 6881 ];
  networking.firewall.allowedUDPPorts = [ 6881 ];

  # Firewall: Allow HAProxy gateway only
  # Managed centrally in reverse-proxy-backends.nix
}
