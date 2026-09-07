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
    # Tesla P40 (Pascal) - use production driver (535 is good, or try 550 for newer features)
    package = config.boot.kernelPackages.nvidiaPackages.legacy_535;  # or .production
    open = false;  # Proprietary driver (required for Pascal)
    nvidiaSettings = false;
    
    # CRITICAL: Enable for proper GPU enumeration and container support
    modesetting.enable = true;
    
    # Disable runtime PM (P40 doesn't support it)
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    
    # Enable persistence mode for headless compute (BOOLEAN, not attrset!)
    nvidiaPersistenced = true;
  };

  # Blacklist nouveau (good)
  boot.blacklistedKernelModules = [ "nouveau" ];

  # Kernel parameters - FIXED for proprietary driver
  boot.kernelParams = [
    "pcie_aspm=off"  # Disable ASPM (prevents PCIe link issues)
    "nvidia-drm.modeset=1"  # Enable DRM modesetting (required for modesetting.enable = true)
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"  # Preserve VRAM across suspend
    # Removed: NVreg_OpenRmEnableUnsupportedGpus (only for open kernel modules)
    # Removed: console=ttyS0 (only if you actually use serial console)
    "fbcon=map:0"  # Keep framebuffer on ASPEED iGPU
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
    config.hardware.nvidia.package
    pciutils
    # Useful for debugging
    nvidia-settings
  ];

  # Optional: Set persistence mode at boot (persistence daemon already enabled above)
  systemd.services.nvidia-persistenced-start = {
    description = "Enable NVIDIA persistence mode";
    after = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pm 1 || true
    '';
    wantedBy = [ "multi-user.target" ];
  };
}
