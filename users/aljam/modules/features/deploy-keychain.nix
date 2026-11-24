{
  pkgs,
  ...
}:

{
  home-manager.users.aljam = {
    home.packages = [ pkgs.keychain ];

    programs.fish.interactiveShellInit = ''
      eval (keychain --eval --quiet ~/.ssh/nixlab_deploy | string collect)
    '';
  };
}
