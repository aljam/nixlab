# DRY: Use shared proxy IP from flake.nix
{
  config,
  lib,
  pkgs,
  ...
}:

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
      "textfile"
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

  # Keep host visibility for system, ZFS, filesystem, and hardware collectors;
  # do not apply ProtectSystem=strict here.
  systemd.services.prometheus-node-exporter.serviceConfig = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
  };
}
