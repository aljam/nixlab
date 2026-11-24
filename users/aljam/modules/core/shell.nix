{ config, pkgs, ... }:

{
  home.packages = [ pkgs.keychain ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""

      eval (keychain --eval --quiet ~/.ssh/nixlab_deploy | string collect)
    '';
    shellAliases = {
      ls = "eza --icons";
      cat = "bat";
      ssh = "ssh";
    };
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
