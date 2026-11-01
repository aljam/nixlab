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
    ++ lib.optionals (
      cfg.networking.servicesBindAddress or "" == "0.0.0.0"
      || cfg.networking.servicesBindAddress or "" == "::"
    ) [
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
    ++ lib.optionals (
      (cfg.services.autobrr.enable or false)
      && (cfg.services.autobrr.settings.host or "") == "0.0.0.0"
    ) [
      "${hostname}: Autobrr must not bind to 0.0.0.0"
    ]
  ) hosts;

  failures = lib.concatLists hostFailures;

  failureReport = pkgs.writeText "service-exposure-failures" (
    lib.concatStringsSep "\n" failures
  );
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
