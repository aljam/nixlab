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
    ../../modules/features/promtail.nix
    ../../modules/hardware/navi-desktop.nix
  ];

  programs.corectrl.enable = true; # AMD Overclocking/Undervolting

  services.nixlab.promtail = {
    enable = true;
    lokiUrl = "http://${config.networking.fleet.r730xd.ip}:3100/loki/api/v1/push";
  };
}
