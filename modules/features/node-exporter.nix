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

  networking.firewall.extraInputRules = lib.mkAfter ''
    ip saddr ${config.networking.fleet.r730xd.ip}
    tcp dport 9100
    accept comment "Prometheus scrape node exporter"
  '';
}
