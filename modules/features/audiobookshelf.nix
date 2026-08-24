# Audiobookshelf audiobook and podcast server

{ config, lib, pkgs, ... }:

let
  cfg = config.modules.features.audiobookshelf;
in
{
  options.modules.features.audiobookshelf = {
    enable = lib.mkEnableOption "Audiobookshelf audiobook and podcast server" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.proxyBackendPorts = [ 13378 ];

    services.audiobookshelf = {
      enable = true;
      host = config.networking.servicesBindAddress;
      port = 13378;
    };
  };
}
