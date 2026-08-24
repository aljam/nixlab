# DRY: Use shared proxy IP from flake.nix
{ config, lib, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 9100 ];

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
  };
}
