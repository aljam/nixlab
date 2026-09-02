# AI NODE - TODO: Reserved for future AI/ML workload support
# Uncomment below when CUDA/GPU compute support is needed
# {
#   imports = [ ../../modules/roles/ai-node.nix ];
#   
#   # Enable NVIDIA GPU for compute workloads
#   hardware.nvidia.containerModes = [ "utility" "compute" "graphics" "video" "display" ];
#   hardware.nvidia.modesetting.enable = true;
#   hardware.nvidia.powerManagement.enable = true;
#   hardware.nvidia.open = true;
#   
#   services.xserver.videoDrivers = [ "nvidia" ];
#   hardware.opengl.enable = true;
#   hardware.opengl.driSupport = true;
#   hardware.opengl.driSupport32Bit = true;
#   
#   environment.systemPackages = [
#     pkgs.cudatoolkit
#     pkgs.cudnn
#     pkgs.nccl
#   ];
# }

{ config, lib, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ../../modules/roles/server-core.nix
    ../../modules/roles/storage-node.nix
    ../../modules/hardware/dell-poweredge.nix
  ];

  # Use stable kernel for server hardware
  boot.kernelPackages = pkgs.linuxPackages_6_1;

  # Server-specific optimizations
  services.cpu-autofreq.enable = true;
  services.thermald.enable = true;

  # ZFS tuning for storage workload
  services.zfs.autoSnapshot.enable = true;
  services.zfs.trim.enable = true;
}
