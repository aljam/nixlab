{ config, pkgs, lib, ... }:

{
  nixpkgs.config.nvidia.acceptLicense = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.enable = false;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    # Tesla P40 (Pascal) requires the legacy 535 driver
    package = config.boot.kernelPackages.nvidiaPackages.legacy_535;
    open = false; 
    nvidiaSettings = false; 
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    
    # Defaults false for headless (R730xd), overridden to true for compute (R730)
    modesetting.enable = lib.mkDefault false;
  };

  boot.blacklistedKernelModules = [ "nouveau" ];

  # Kernel parameters for headless enterprise Pascal cards
  boot.kernelParams = [
    "pcie_aspm=off"
    "nvidia-drm.modeset=0"
    "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1" # Forces P40 Pascal support
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "console=tty0"           # Directs kernel messages to primary system console
    "console=ttyS0,115200n8" # Enables iDRAC serial redirection
    "fbcon=map:0"            # Forces framebuffer console to slot 0 (ASPEED)
  ];

  systemd.services."getty@tty1".enable = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
    config.hardware.nvidia.package
    pciutils
  ];
}
