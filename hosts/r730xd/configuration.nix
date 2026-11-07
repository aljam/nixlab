{
  config,
  pkgs,
  lib,
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
    ../../modules/features/loki.nix
    ../../modules/features/promtail.nix
    ../../modules/features/matrix-synapse.nix
    ../../modules/features/matrix-rtc.nix
    ../../modules/features/static-site.nix
    ../../modules/features/radio.nix
    ../../modules/features/radio-visualizer.nix
    ../../modules/features/peertube.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_6_1;

  boot.kernelParams = [ "zfs.zfs_arc_max=68719476736" ];

  networking.hostId = "d2083fdc"; # Required for ZFS

  modules.features.prometheus-server.postgresCaFile = config.sops.secrets.pfsense-root-ca.path;

  modules.features.static-site.enable = true;
  modules.features.radio.enable = true;
  modules.features.radio-visualizer.enable = true;
  modules.features.vaultwarden.enable = true;
  modules.features.peertube.enable = true;

  services.nixlab.loki = {
    enable = true;
    listenAddress = config.networking.fleet.r730xd.ip;
  };

  services.nixlab.promtail = {
    enable = true;
    lokiUrl = "http://${config.networking.fleet.r730xd.ip}:3100/loki/api/v1/push";
  };

  services.nixlab.grafana.lokiUrl = "http://${config.networking.fleet.r730xd.ip}:3100";
}
