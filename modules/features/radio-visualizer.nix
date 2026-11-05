{ lib, config, pkgs, ... }:
let
  cfg = config.modules.features.radio-visualizer;
  icecastMount = "/stream";
  visualizerHtml = builtins.readFile ./radio-visualizer.html;
  visualizerRoot = pkgs.writeTextDir "index.html" visualizerHtml;
  listenAddress = config.networking.servicesBindAddress or "0.0.0.0";
in
{
  options.modules.features.radio-visualizer.enable =
    lib.mkEnableOption "Butterchurn visualizer for the Icecast radio";

  config = lib.mkIf cfg.enable {
    # The pfSense HAProxy gateway terminates public TLS and forwards to this
    # LAN-only backend. Do not enable direct HTTP/HTTPS ingress here.
    networking.proxyBackendPorts = [ 8090 ];

    services.nginx = {
      enable = true;
      virtualHosts."radio-backend" = {
        listen = [
          {
            addr = listenAddress;
            port = 8090;
          }
        ];

        locations."= /" = {
          root = visualizerRoot;
          tryFiles = "/index.html =404";
        };

        locations."= /index.html" = {
          root = visualizerRoot;
        };

        locations.${icecastMount} = {
          proxyPass = "http://127.0.0.1:8000${icecastMount}";
          extraConfig = ''
            proxy_set_header Host $host;
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
