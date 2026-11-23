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
    ../../modules/roles/storage-node.nix
    ../../modules/features/nvidia-headless.nix
    ../../modules/features/disk-health.nix
  ];

  networking.hostId = "acccc16e"; # Required for ZFS

  environment.systemPackages = with pkgs; [
    cudatoolkit
  ];

  modules.features.disk-health.enable = true;
}
