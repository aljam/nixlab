{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/desktop-node.nix
    ../../modules/hardware/system76-laptop.nix
  ];
}
