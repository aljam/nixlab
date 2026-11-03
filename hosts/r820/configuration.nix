{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/roles/server-core.nix
    ../../modules/features/libvirt.nix
    ../../modules/features/postgres.nix
    ../../modules/features/nix-builder.nix
    ../../modules/features/mail-server.nix
    #../../modules/roles/mail-node.nix
  ];

  roles.server.enable = true;

  programs.fish.enable = true;

  # Remote builder configuration
  nix.settings.trusted-users = [ "root" "aljam" ];
  nix.settings.allowed-users = [ "@users" ];
}
