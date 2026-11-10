{ config, pkgs, ... }:

{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # Required for 32-bit audio in Fightcade/Wine
    pulse.enable = true;
  };
}
