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
          (final: prev: {
            millennium-typescript-bun-deps = prev.millennium-typescript-bun-deps.overrideAttrs (old: {
              outputHash = "";  # Use lib.fakeHash or empty string
            });
          })
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
}
