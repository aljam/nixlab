{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.radio-visualizer;
  radioDomain = "radio.derezzed.info";
  icecastMount = "/stream";
  visualizerHtml = builtins.readFile ./radio-visualizer.html;
  visualizerRoot = pkgs.writeTextDir "index.html" visualizerHtml;
in
{
  options.modules.features.radio-visualizer.enable =
    lib.mkEnableOption "Butterchurn visualizer for the Icecast radio";

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts.${radioDomain} = {
        enableACME = true;
        forceSSL = true;

        locations."= /" = {
          root = visualizerRoot;
          tryFiles = "/index.html =404";
        };

        locations."= /index.html" = {
          root = visualizerRoot;
        };

        locations.${icecastMount} = {
          proxyPass = "http://127.0.0.1:8000${icecastMount}";
          proxySetHeader.Host = "$host";
          extraConfig = ''
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 3600s;
          '';
        };

        locations."/status.xsl" = {
          proxyPass = "http://127.0.0.1:8000/status.xsl";
        };
      };
    };
  };
}
