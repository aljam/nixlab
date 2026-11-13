# Fleet-wide evaluation checks for service exposure and security invariants.
#
# This complements modules/features/security-policy.nix: the policy module
# evaluates within each host configuration, while this check evaluates the
# fully composed fleet and fails if any host regresses.
{
  pkgs ? import <nixpkgs> { },
  hosts ? { },
}:

let
  inherit (pkgs) lib;

  hostFailures = lib.mapAttrsToList (
    hostname: host:
    let
      cfg = host.config;
      proxyPorts = cfg.networking.proxyBackendPorts or [ ];
      postgresAuth = cfg.services.postgresql.authentication or "";
      postgresPort = cfg.services.postgresql.settings.port or 5432;
      sopsSecrets = lib.attrValues (cfg.sops.secrets or { });
      lokiEnabled = cfg.services.nixlab.loki.enable or false;
      lokiRetentionEnabled = cfg.services.loki.configuration.compactor.retention_enabled or false;
      lokiRetentionPeriod = cfg.services.loki.configuration.limits_config.retention_period or "";

      peertubeEnabled = cfg.services.peertube.enable or false;
      peertubeSettings = cfg.services.peertube.settings or { };
      peertubeListener = peertubeSettings.listen or { };
      peertubeListenerAddress = peertubeListener.hostname or "";

      livekitContainer = (cfg.virtualisation.oci-containers.containers or { }).livekit or null;
      matrixRtcEnabled = livekitContainer != null;
    in
    lib.optionals (lib.elem 5050 proxyPorts) [
      "${hostname}: pgAdmin port 5050 must not be exposed through HAProxy"
    ]
    ++ lib.optionals (lib.elem 8111 proxyPorts) [
      "${hostname}: Shoko port 8111 must remain LAN-only"
    ]
    ++ lib.optionals (lib.elem postgresPort proxyPorts) [
      "${hostname}: PostgreSQL port ${toString postgresPort} must not be exposed through HAProxy"
    ]
    ++ lib.optionals (lib.elem 9090 proxyPorts) [
      "${hostname}: Prometheus port 9090 must not be exposed through HAProxy"
    ]
    ++ lib.optionals (lib.elem 9115 proxyPorts) [
      "${hostname}: Prometheus Blackbox exporter port 9115 must not be exposed through HAProxy"
    ]
    ++ lib.optionals (lib.elem 9093 proxyPorts) [
      "${hostname}: Alertmanager port 9093 must not be exposed through HAProxy"
    ]
    ++ lib.optionals (lokiEnabled && lib.elem 3100 proxyPorts) [
      "${hostname}: Loki port 3100 must not be exposed through HAProxy"
    ]
    ++ lib.optionals (lokiEnabled && !lokiRetentionEnabled) [
      "${hostname}: Loki retention must be enabled so security logs do not accumulate indefinitely"
    ]
    ++ lib.optionals (lokiEnabled && lokiRetentionPeriod == "") [
      "${hostname}: Loki must define a retention period"
    ]
    ++
      lib.optionals
        (
          cfg.networking.servicesBindAddress or "" == "0.0.0.0"
          || cfg.networking.servicesBindAddress or "" == "::"
        )
        [
          "${hostname}: networking.servicesBindAddress must not bind to every interface"
        ]
    ++ lib.optionals (lib.hasInfix "host all all" postgresAuth) [
      "${hostname}: PostgreSQL authentication must not contain broad host/all/all rules"
    ]
    ++ lib.concatMap (
      secret:
      lib.optionals (secret.sopsFile or null == null) [
        "${hostname}: SOPS secret ${secret.name or "?"} must declare sopsFile"
      ]
      ++ lib.optionals (secret.owner or null == null) [
        "${hostname}: SOPS secret ${secret.name or "?"} must declare owner"
      ]
      ++ lib.optionals (secret.mode or null == null) [
        "${hostname}: SOPS secret ${secret.name or "?"} must declare mode"
      ]
    ) sopsSecrets
    ++
      lib.optionals
        ((cfg.services.autobrr.enable or false) && (cfg.services.autobrr.settings.host or "") == "0.0.0.0")
        [
          "${hostname}: Autobrr must not bind to 0.0.0.0"
        ]
    ++ lib.optionals (peertubeEnabled && !(lib.elem 9000 proxyPorts)) [
      "${hostname}: PeerTube must expose its HTTP service through HAProxy port 9000"
    ]
    ++
      lib.optionals
        (
          peertubeEnabled
          && (
            peertubeListenerAddress == ""
            || peertubeListenerAddress == "0.0.0.0"
            || peertubeListenerAddress == "::"
          )
        )
        [
          "${hostname}: PeerTube must bind its HTTP listener to an explicit service address"
        ]
    ++ lib.optionals (matrixRtcEnabled && !(lib.elem 7880 proxyPorts)) [
      "${hostname}: Matrix RTC must expose the LiveKit API through HAProxy port 7880"
    ]
    ++ lib.optionals (matrixRtcEnabled && !(lib.elem 8081 proxyPorts)) [
      "${hostname}: Matrix RTC must expose the JWT service through HAProxy port 8081"
    ]
    ++
      lib.optionals
        (
          matrixRtcEnabled
          && (lib.elem 7881 proxyPorts || lib.elem 50100 proxyPorts || lib.elem 50200 proxyPorts)
        )
        [
          "${hostname}: Matrix RTC media ports must not be exposed through HAProxy"
        ]
  ) hosts;

  failures = lib.concatLists hostFailures;

  failureReport = pkgs.writeText "service-exposure-failures" (lib.concatStringsSep "\n" failures);
in
pkgs.runCommand "service-exposure-checks"
  {
    inherit failureReport;
  }
  ''
    if [ -s "$failureReport" ]; then
      echo "Service exposure checks failed:" >&2
      cat "$failureReport" >&2
      exit 1
    fi

    touch "$out"
  ''
