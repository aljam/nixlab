# Matrix RTC (LiveKit and lk-jwt-service).
#
# Exposure model:
# - HAProxy may reach the LiveKit API (7880) and JWT service (8081) through
#   `networking.proxyBackendPorts`.
# - The RTC TCP port and UDP media range are published directly because WebRTC
#   clients need them; they are intentionally outside the HAProxy model.
# - `livekit-jwt-env` supplies the shared LiveKit API secret to both containers.
# - LiveKit state is ephemeral; no persistent volume is declared.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  rtcDomain = "rtc.derezzed.info";

  hostIp = config.networking.fleet.r730xd.ip;

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

      # Nix indented strings treat backslashes literally, so use one backslash
      # for each POSIX shell line continuation.
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
  networking.proxyBackendPorts = [
    7880
    8081
  ];

  environment.systemPackages = [ livekitTestToken ];

  sops.secrets = {
    livekit-jwt-env = {
      sopsFile = ../../secrets/matrix.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  virtualisation.oci-containers.containers = {
    livekit = {
      image = "docker.io/livekit/livekit-server:latest";
      autoStart = true;
      ports = [
        "${hostIp}:7880:7880"
        "7881:7881"
        "50100-50200:50100-50200/udp"
      ];
      environmentFiles = [ config.sops.secrets.livekit-jwt-env.path ];
      cmd = [
        "--config"
        "/etc/livekit/livekit.yaml"
      ];
      volumes = [ "${livekitConfig}:/etc/livekit/livekit.yaml:ro" ];
    };

    lk-jwt-service = {
      image = "ghcr.io/element-hq/lk-jwt-service:latest";
      autoStart = true;
      ports = [ "${hostIp}:8081:8081" ];
      environment = {
        LIVEKIT_JWT_BIND = ":8081";
        LIVEKIT_URL = "wss://${rtcDomain}";
        LIVEKIT_KEY = "matrixrtc";
      };
      environmentFiles = [ config.sops.secrets.livekit-jwt-env.path ];
    };
  };
}
