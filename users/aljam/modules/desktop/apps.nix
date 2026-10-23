{ config, pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs; [
    deadbeef-with-plugins
    discord
    betterdiscordctl
    telegram-desktop
    mpv
    obsidian
    librewolf
    gimp
    krita
    blender
    qbittorrent
    inkscape
    super-slicer
    davinci-resolve
    element-desktop
    libreoffice-qt
    hunspell
    hunspellDicts.en_US
    hyphenDicts.en_US
    pkgs-stable.lutris
    heroic
    protonup-qt
    mangohud
    corectrl
    vscodium
    jetbrains.idea
    unnamed-sdvx-clone
    qjackctl
    # Replaces 'stable' - has the multilib + staging patches for Sound Voltex (EAC)
    wineWow64Packages.stagingFull
    winetricks
    yazi
    imv
    pavucontrol
    pamixer
    cliphist
    libnotify
    reaper
    lmms
  ];
}
