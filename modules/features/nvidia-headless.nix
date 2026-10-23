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
    # Tesla P40 (Pascal) requires the legacy proprietary driver.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_535;
    open = false;
    nvidiaSettings = false;

    modesetting.enable = true;

    # The P40 does not support runtime power management.
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Enable the NVIDIA persistence daemon for headless compute.
    nvidiaPersistenced = true;
  };

  boot.blacklistedKernelModules = [ "nouveau" ];

  boot.kernelParams = [
    # Disable ASPM to avoid PCIe link issues.
    "pcie_aspm=off"

    # Required by hardware.nvidia.modesetting.enable.
    "nvidia-drm.modeset=1"

    # Preserve VRAM allocations across suspend.
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"

    # Keep the framebuffer on the ASPEED iGPU.
    "fbcon=map:0"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
    config.hardware.nvidia.package
    pciutils
  ];
}
