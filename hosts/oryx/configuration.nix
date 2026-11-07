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
    ../../modules/hardware/system76-laptop.nix
  ];

  services.nixlab.promtail = {
    enable = true;
    lokiUrl = "http://${config.networking.fleet.r730xd.ip}:3100/loki/api/v1/push";
  };
}
