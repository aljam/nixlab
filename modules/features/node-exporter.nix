# DRY: Use shared proxy IP from flake.nix
{ config, lib, pkgs, ... }:

{
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

  services.smartd = {
    enable = true;
    autodetect = true;
  };

  services.prometheus.exporters.smartctl = {
    enable = true;
    port = 9633;
  };
}
