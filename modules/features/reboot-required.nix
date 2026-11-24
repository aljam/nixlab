{ lib, ... }:
{
  options.modules.features.reboot-required.enable = lib.mkEnableOption "reboot-required monitoring";
}
