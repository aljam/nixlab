{
  config,
  pkgs,
  lib,
  ...
}:

{
  boot.loader.grub.gfxmodeEfi = "1920x1200";
  boot.loader.grub.gfxmodeBios = "1920x1200";
  boot.loader.grub.gfxpayloadEfi = "keep";
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_EnableGpuFirmware=1"
    "system76_acpi.brightness_hwmon=1"
    "nvidia-drm.modeset=1"
  ];

  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    nvidiaPersistenced = true;
    powerManagement.enable = true;
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  hardware.system76.kernel-modules.enable = true;
  hardware.system76.firmware-daemon.enable = true;
  hardware.system76.power-daemon.enable = true;

  services.fwupd.enable = true;
  services.system76-scheduler.enable = true;
  services.thermald.enable = false;
  services.power-profiles-daemon.enable = false;

  powerManagement.cpuFreqGovernor = "performance";
}
