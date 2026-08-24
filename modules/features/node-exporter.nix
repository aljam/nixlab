# DRY: Use shared proxy IP from flake.nix
{ config, lib, pkgs, ... }:

{
  networking.proxyBackendPorts = [ 9100 ];

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = lib.mkForce [
      "systemd"
      "cpu"
      "diskstats"
      "filesystem"
      "netdev"
      "zfs"
      "hwmon"
      "nvme"
    ];
  };
}
