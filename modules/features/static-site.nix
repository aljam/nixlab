{
  config,
  lib,
  pkgs,
  ...
}:
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

    # The static site is served from an immutable Nix-store path. Apply
    # conservative nginx sandboxing without ProtectSystem, ProtectProc, or
    # ProcSubset, which can interfere with nginx logging, caching, PID, and
    # worker-process behavior.
    systemd.services.nginx.serviceConfig = {
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;

      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      RestrictRealtime = true;
    };
  };
}
