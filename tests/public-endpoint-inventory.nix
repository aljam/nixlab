# Validate the public endpoint inventory consumed by edge-security checks
# and Prometheus Blackbox probes.
{
  pkgs ? import <nixpkgs> { },
}:

let
  inherit (pkgs) lib;

  inventory = builtins.fromJSON (builtins.readFile ../docs/public-endpoints.json);
  endpoints = inventory.endpoints or [ ];

  endpointFailures = lib.concatMap (
    endpoint:
    let
      name = endpoint.name or null;
      url = endpoint.url or null;
      expectedStatus = endpoint.expected_status or null;
      requireHsts = endpoint.require_hsts or null;
      minTlsVersion = endpoint.min_tls_version or null;

      https = url != null && lib.hasPrefix "https://" url;
      positiveStatus = expectedStatus != null && expectedStatus > 0;
      hstsRequired = requireHsts == true;
      tlsVersionSupported = minTlsVersion != null && lib.elem minTlsVersion [ "1.2" "1.3" ];
    in
    lib.optionals (name == null || name == "") [
      "Public endpoint must declare a non-empty name: ${builtins.toJSON endpoint}"
    ]
    ++ lib.optionals (url == null || url == "") [
      "Public endpoint ${toString name} must declare a URL"
    ]
    ++ lib.optionals (!https) [
      "Public endpoint ${toString name} must use HTTPS: ${toString url}"
    ]
    ++ lib.optionals (!positiveStatus) [
      "Public endpoint ${toString name} must declare a positive expected_status"
    ]
    ++ lib.optionals (!hstsRequired) [
      "Public endpoint ${toString name} must require HSTS"
    ]
    ++ lib.optionals (!tlsVersionSupported) [
      "Public endpoint ${toString name} must require TLS 1.2 or newer; got ${toString minTlsVersion}"
    ]
  ) endpoints;

  duplicateNames =
    lib.lists.subtractLists
      (lib.unique (map (endpoint: endpoint.name or "") endpoints))
      (map (endpoint: endpoint.name or "") endpoints);

  failures =
    lib.optionals (endpoints == [ ]) [ "Public endpoint inventory must contain at least one endpoint" ]
    ++ map (name: "Public endpoint name is duplicated: ${name}") duplicateNames
    ++ endpointFailures;

  failureReport = pkgs.writeText "public-endpoint-inventory-failures" (
    lib.concatStringsSep "\n" failures
  );
in
pkgs.runCommand "public-endpoint-inventory-checks"
  {
    inherit failureReport;
  }
  ''
    if [ -s "$failureReport" ]; then
      echo "Public endpoint inventory checks failed:" >&2
      cat "$failureReport" >&2
      exit 1
    fi

    touch "$out"
  ''
