{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mgba
    melonds
    mesen
    retroarch-full
    flips
    asar
    imhex
    rgbds
    tiled
    pcsx2
    rpcs3
    ppsspp
    dolphin-emu
    cemu
  ];

  # Grants Dolphin raw access to GC controller adapters
  services.udev.packages = [ pkgs.dolphin-emu ];
}
