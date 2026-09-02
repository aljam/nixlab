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

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/roles/server-core.nix
    ../../modules/roles/storage-node.nix
    # ../../modules/roles/ai-node.nix
    # ../../modules/features/nvidia-headless.nix
  ];

  networking.hostId = "acccc16e"; # Required for ZFS

  boot.kernelPackages = pkgs.linuxPackages_6_1;  

  # hardware.nvidia-container-toolkit.enable = true; # Passes the P40s into Docker

  # hardware.nvidia = {
  #   modesetting.enable = true; # Overrides the headless module default
  #   nvidiaPersistenced = true; # Prevents power-state latency drops during AI training
  # };

  #nixpkgs.config.cudaSupport = true;

  environment.systemPackages = with pkgs; [
    cudatoolkit
    linuxPackages.nvidia_x11
  ];

}
