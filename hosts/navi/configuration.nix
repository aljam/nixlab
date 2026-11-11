{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/desktop-node.nix
    ../../modules/hardware/navi-desktop.nix
  ];

  programs.corectrl.enable = true; # AMD Overclocking/Undervolting
}
