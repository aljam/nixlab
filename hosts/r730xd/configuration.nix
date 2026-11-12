{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/roles/server-core.nix
    ../../modules/features/nvidia-headless.nix
    ../../modules/roles/media-node.nix
    ../../modules/roles/storage-node.nix
    ../../modules/features/prometheus-server.nix
    ../../modules/features/prometheus-alerts.nix
    ../../modules/features/drift-monitoring.nix
    ../../modules/features/loki.nix
    ../../modules/features/restic-backup.nix
    ../../modules/features/matrix-synapse.nix
    ../../modules/features/matrix-rtc.nix
    ../../modules/features/static-site.nix
    ../../modules/features/radio.nix
    ../../modules/features/radio-visualizer.nix
    ../../modules/features/peertube.nix
  ];

  boot.kernelParams = [ "zfs.zfs_arc_max=6871947636" ];

  networking.hostId = "d2083fdc"; # Required for ZFS

  services.resolved.enable = true;

  # Re-enable after the PostgreSQL server certificate on r820 is issued by
  # the CA trusted through `postgresCaFile`. The module currently generates a
  # self-signed certificate, which cannot validate against the pfSense root CA.
  # modules.features.prometheus-server.postgresCaFile =
  #   config.sops.secrets.pfsense-root-ca-prometheus.path;

  modules.features.static-site.enable = true;
  modules.features.radio.enable = true;
  modules.features.radio-visualizer.enable = true;
  modules.features.vaultwarden.enable = true;
  modules.features.peertube.enable = true;

  modules.features.restic-backup = {
    enable = true;

    jobs.peertube-media = {
      repository = "/var/lib/restic-backup/repo";
      paths = [ "/var/lib/peertube/storage" ];
      schedule = "*-*-* 02:00:00";
      randomizedDelay = "15m";
    };

    jobs.matrix-media = {
      repository = "/var/lib/restic-backup/repo";
      paths = [ "/var/lib/matrix-synapse" ];
      schedule = "*-*-* 02:30:00";
      randomizedDelay = "15m";
    };

    jobs.vaultwarden-data = {
      repository = "/var/lib/restic-backup/repo";
      paths = [ "/var/lib/vaultwarden" ];
      schedule = "*-*-* 02:30:00";
      randomizedDelay = "15m";
    };
  };

  services.nixlab.loki = {
    enable = true;
    listenAddress = config.networking.fleet.r730xd.ip;
  };

  services.nixlab.grafana.lokiUrl = "http://${config.networking.fleet.r730xd.ip}:3100";
}
