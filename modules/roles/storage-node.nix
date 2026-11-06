{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../features/sanoid.nix
    ../features/zfs-base.nix
  ];
}
