{ config, lib, pkgs, inputs, ... }:

{
  hardware.steam-hardware.enable = true;
  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };
  programs.gamemode = {
    enable = true;
  };
  programs.gamescope.enable = true;
  programs.steam = {
    enable = true;
    package =
      let
        millenniumPkgs = pkgs.appendOverlays [
          inputs.millennium.overlays.default
        ];
      in
      millenniumPkgs.millennium-steam.override {
        extraPkgs = (pkgs: with pkgs; [
          gamemode
          libxi
          libxcursor
          libxinerama
          libxscrnsaver
          libpulseaudio
          libvorbis
          libkrb5
          keyutils
          at-spi2-atk
          libpng
        ]);
      };
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
      nur.repos.vladexa.proton-cachyos
    ];
    protontricks.enable = true;
  };

  programs.gamemode.settings.general.renice = 10;
  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;   # required by many Proton titles / DX12
    "vm.swappiness" = 10;
    "net.core.rmem_max" = 2500000;     # helps Steam downloads
  };
  services.scx.enable = true;          # sched_ext, pairs well with your CachyOS kernel
  hardware.xpadneo.enable = true;      # Xbox controllers over BT
  programs.gamescope.capSysNice = true;

}
