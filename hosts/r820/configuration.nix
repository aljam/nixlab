{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/dell-poweredge.nix
    ../../modules/roles/server-core.nix 
    ../../modules/features/libvirt.nix
    ../../modules/features/postgres.nix
    #../../modules/roles/mail-node.nix
  ];

  # Remote builder configuration
  nix.settings.trusted-users = [ "root" "aljam" ];
  nix.settings.allowed-users = [ "@users" ];
}
