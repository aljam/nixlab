{ config, lib, pkgs, ... }:
let
  rtcDomain = "rtc.derezzed.info";
  matrixDomain = "matrix.derezzed.info";

  livekitConfig = pkgs.writeText "livekit.yaml" ''
    port: 7880
    rtc:
      tcp_port: 7881
      port_range_start: 50100
      port_range_end: 50200
      use_external_ip: true
    room:
      auto_create: false
    keys:
      matrixrtc: "$LIVEKIT_SECRET"
  '';
in
{
  networking.proxyBackendPorts = [ 7880 8081 ];

  networking.firewall = {
    allowedTCPPorts = [ 7881 ];
    allowedUDPPortRanges = [
      { from = 50100; to = 50200; }
    ];
  };

  sops.secrets = {
    livekit-secret = { };
    livekit-jwt-env = { };
  };

  virtualisation.oci-containers.containers = {
    livekit = {
      image = "docker.io/livekit/livekit-server:latest";
      autoStart = true;
      ports = [
        "192.168.1.2:7880:7880"
        "7881:7881"
        "50100-50200:50100-50200/udp"
      ];
      environmentFiles = [ config.sops.secrets.livekit-secret.path ];
      cmd = [ "--config" "/etc/livekit/livekit.yaml" ];
      volumes = [ "${livekitConfig}:/etc/livekit/livekit.yaml:ro" ];
    };

    lk-jwt-service = {
      image = "ghcr.io/element-hq/lk-jwt-service:latest";
      autoStart = true;
      ports = [ "192.168.1.2:8081:8080" ];
      environment = {
        LIVEKIT_URL = "wss://${rtcDomain}/livekit/sfu";
        LIVEKIT_KEY = "matrixrtc";
        LIVEKIT_FULL_ACCESS_HOMESERVERS = matrixDomain;
      };
      environmentFiles = [ config.sops.secrets.livekit-jwt-env.path ];
    };
  };
}
