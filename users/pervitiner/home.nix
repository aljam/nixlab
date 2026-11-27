{ config, pkgs, ... }:

{
  home.username = "pervitiner";
  home.homeDirectory = "/home/pervitiner";
  home.stateVersion = "26.05";

  imports = [
    ../aljam/modules/core/packages.nix
    ../aljam/modules/core/shell.nix
  ];

  programs.home-manager.enable = true;
}
