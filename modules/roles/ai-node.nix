# TODO: AI/ML Workstation Role - Planned Feature
# This role is reserved for future AI/ML workstation configuration.
# When enabled, it will provide:
# - NVIDIA CUDA drivers and toolkit
# - cuDNN and NCCL libraries
# - Python ML stack (PyTorch, TensorFlow, JAX)
# - Container runtime with GPU support
#
# Do not remove this file - it's intentionally kept for future use.

{ config, lib, pkgs, ... }: {
  # AI NODE - Currently disabled, reserved for future use
  # Uncomment and configure when AI/ML workload support is needed

  # hardware.nvidia.containerModes = [ "utility" "compute" "graphics" "video" "display" ];
  # hardware.nvidia.modesetting.enable = true;
  # hardware.nvidia.powerManagement.enable = true;
  # hardware.nvidia.open = true;

  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.opengl.enable = true;
  # hardware.opengl.driSupport = true;
  # hardware.opengl.driSupport32Bit = true;

  # environment.systemPackages = [
  #   pkgs.cudatoolkit
  #   pkgs.cudnn
  #   pkgs.nccl
  # ];

  # environment.variables = {
  #   CUDA_HOME = "${pkgs.cudatoolkit}";
  #   LD_LIBRARY_PATH = "${pkgs.cudatoolkit.lib}/lib:$LD_LIBRARY_PATH";
  # };
}
