{
  config,
  pkgs,
  lib,
  ...
}:

{
  boot.loader.grub.gfxmodeEfi = "3440x1440";
  boot.loader.grub.gfxmodeBios = "3440x1440";
  boot.loader.grub.gfxpayloadEfi = "keep";

  boot.extraModprobeConfig = "options usb-storage use_uas=0";
  boot.kernelParams = [
    "usb-storage.quirks=152d:0551:u"
    "usbcore.autosuspend=-1"
  ];
}
