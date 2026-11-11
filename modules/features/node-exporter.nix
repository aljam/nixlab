{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.features.node-exporter;
in
{
  options.modules.features.node-exporter.textfileDirectory = lib.mkOption {
    type = lib.types.path;
    default = "/var/lib/node-exporter/textfile";
    readOnly = true;
    description = ''
      Directory read by node_exporter's textfile collector. Units that publish
      their own metrics write `*.prom` files here.
    '';
  };

  config = {
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
      # Without a directory the textfile collector is enabled but reads nothing.
      extraFlags = [ "--collector.textfile.directory=${cfg.textfileDirectory}" ];
    };

    # Owned here so that metric writers neither create the directory themselves
    # nor depend on another writer having run first.
    systemd.tmpfiles.rules = [
      "d ${cfg.textfileDirectory} 0750 node-exporter node-exporter - -"
    ];

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
  };
}
