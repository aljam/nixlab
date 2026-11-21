{ config, lib, pkgs, ... }:

{
  options.modules.features.developerTools.enable =
    lib.mkEnableOption "developer and API debugging tools";

  config = lib.mkIf config.modules.features.developerTools.enable {
    environment.systemPackages = with pkgs; [
      jq
      yq
      httpie
      curl
      lazygit
      gh
      delta
    ];
  };
}
