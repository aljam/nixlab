{ config, lib, pkgs, ... }:
let
  siteRoot = pkgs.runCommand "derezzed-info-site" { } ''
    mkdir -p $out
    cp ${./static/derezzed-info/index.html} $out/index.html
  '';
in
{
  options.modules.features.static-site = {
    enable = lib.mkEnableOption "the derezzed.info static landing site";
  };

  config = lib.mkIf config.modules.features.static-site.enable {
    networking.proxyBackendPorts = [ 8083 ];

    services.nginx = {
      enable = true;

      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts."derezzed-info" = {
        serverName = "derezzed.info www.derezzed.info";

        listen = [
          {
            addr = config.networking.servicesBindAddress;
            port = 8083;
          }
        ];

        root = siteRoot;

        locations."/" = {
          index = "index.html";
        };

        locations."= /health".return = "200 'ok'";
      };
    };
  };
}
