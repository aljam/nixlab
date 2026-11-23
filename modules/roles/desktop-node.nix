{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.gen1recomp = {
    enable = true;

    # Verified with:
    # nix store prefetch-file --json \
    #   'https://github.com/bryanthaboi/gen1recomp/releases/download/v0.2.57/gen1recomp-0.2.57.love'
    hash = "sha256-lj9oPiWmrNPvNyYb+GbEmrdfqn00jzwxQfbXVoTg+40=";
  };
}
