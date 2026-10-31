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
  '';

  livekitTestToken = pkgs.writeShellApplication {
    name = "livekit-test-token";
    runtimeInputs = [ pkgs.livekit-cli ];
    text = ''
      set -euo pipefail
      secret_file="''${1:-${config.sops.secrets.livekit-jwt-env.path}}"
      secret="$(sed -n 's/^LIVEKIT_SECRET=//p' "$secret_file")"

      if [[ -z "$secret" ]]; then
        echo "LIVEKIT_SECRET not found in $secret_file" >&2
        exit 1
      fi

      exec lk token create \
        --api-key matrixrtc \
        --api-secret "$secret" \
        --join \
        --room connection-test \
        --identity tester \
        --valid-for 1h
    '';
  };
in
{
  networking.proxyBackendPorts = [ 7880 8081 ];

  environment.systemPackages = [ livekitTestToken ];

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
      environmentFiles = [ config.sops.secrets.livekit-jwt-env.path ];
      cmd = [ "--config" "/etc/livekit/livekit.yaml" ];
      volumes = [ "${livekitConfig}:/etc/livekit/livekit.yaml:ro" ];
    };

    lk-jwt-service = {
      image = "ghcr.io/element-hq/lk-jwt-service:latest";
      autoStart = true;
      ports = [ "192.168.1.2:8081:8081" ];
      environment = {
        LIVEKIT_JWT_BIND = ":8081";
        LIVEKIT_URL = "wss://rtc.derezzed.info";
        LIVEKIT_KEY = "matrixrtc";
      };
      environmentFiles = [ config.sops.secrets.livekit-jwt-env.path ];
    };
  };
}
