{ config, pkgs, ... }:

{
  home.username = "aljam";
  home.homeDirectory = "/home/aljam";
  home.stateVersion = "26.05";

  imports = [
    ./modules/core/git.nix
    ./modules/core/shell.nix
    ./modules/core/nvim.nix
    ./modules/core/opencode.nix
    ./modules/core/packages.nix
    ./modules/core/ssh-agent.nix
  ];

  programs.home-manager.enable = true;
}
