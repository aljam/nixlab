{
  config,
  pkgs,
  lib,
  ...
}:

{
  assertions = [
    {
      assertion = !(lib.hasInfix "SSH_AUTH_SOCK=" config.programs.fish.interactiveShellInit);
      message = "Fish configuration must not contain Bash-style SSH_AUTH_SOCK assignments; use Fish command substitution with keychain --eval instead.";
    }
  ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""
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
