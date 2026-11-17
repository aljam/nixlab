# Public-service recovery-readiness drill.
#
# Validates that the repository retains the controls needed to recover a
# public-facing service: an intentional HTTPS endpoint inventory and a
# recovery matrix covering DNS, TLS, reverse proxy, public endpoints,
# upstream services, authentication, monitoring, and recovery sequencing.
#
# This is a static recovery-readiness check. It does not query production
# endpoints or modify production DNS, TLS, firewall, reverse-proxy, or
# service configuration.
{
  pkgs ? import <nixpkgs> { },
}:

let
  inherit (pkgs) lib;

  inventory = builtins.fromJSON (builtins.readFile ../docs/public-endpoints.json);
  endpoints = inventory.endpoints or [ ];

  positiveStatus =
    status:
    if lib.isList status then
      status != [ ] && lib.all (item: lib.isInt item && item > 0) status
    else
      lib.isInt status && status > 0;

  endpointFailures = lib.concatMap (
    endpoint:
    let
      name = endpoint.name or null;
      url = endpoint.url or null;
      expectedStatus = endpoint.expected_status or null;
      requireHsts = endpoint.require_hsts or null;
      minTlsVersion = endpoint.min_tls_version or null;

      https = url != null && lib.hasPrefix "https://" url;
      statusValid = positiveStatus expectedStatus;
      hstsRequired = requireHsts == true;
      tlsVersionSupported =
        minTlsVersion != null
        && lib.elem minTlsVersion [
          "1.2"
          "1.3"
        ];
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
    ++ lib.optionals (!statusValid) [
      "Public endpoint ${toString name} must declare a positive expected_status or a non-empty list of positive expected statuses"
    ]
    ++ lib.optionals (!hstsRequired) [
      "Public endpoint ${toString name} must require HSTS"
    ]
    ++ lib.optionals (!tlsVersionSupported) [
      "Public endpoint ${toString name} must require TLS 1.2 or newer; got ${toString minTlsVersion}"
    ]
  ) endpoints;

  endpointNames = map (endpoint: endpoint.name or "") endpoints;

  duplicateNames = lib.unique (
    lib.filter (name: lib.count (other: other == name) endpointNames > 1) endpointNames
  );

  recoveryMatrix = builtins.readFile ../docs/runbooks/public-service-recovery-matrix.md;

  requiredRecoveryTopics = [
    "DNS recovery"
    "TLS recovery"
    "Reverse-proxy recovery"
    "Public-endpoint recovery"
    "Upstream-service recovery"
    "Authentication recovery"
    "Monitoring recovery"
    "Recovery sequence"
    "Pass criteria"
  ];

  missingRecoveryTopics = lib.filter (
    topic: !(lib.hasInfix topic recoveryMatrix)
  ) requiredRecoveryTopics;

  requiredRecoveryLinks = [
    "docs/PUBLIC_SERVICES.md"
    "docs/public-endpoints.json"
    "docs/NETWORKING.md"
    "docs/audits/certificate-tls-lifecycle.md"
    "docs/audits/dns-domain-management.md"
    "docs/audits/network-exposure-firewall.md"
    "docs/audits/monitoring-alerting.md"
    "docs/runbooks/incident-severity.md"
    "docs/runbooks/incident-evidence.md"
  ];

  missingRecoveryLinks = lib.filter (link: !(lib.hasInfix link recoveryMatrix)) requiredRecoveryLinks;

  failures =
    lib.optionals (endpoints == [ ]) [ "Public endpoint inventory must contain at least one endpoint" ]
    ++ map (name: "Public endpoint name is duplicated: ${name}") duplicateNames
    ++ endpointFailures
    ++ map (
      topic: "Public-service recovery matrix is missing recovery topic: ${topic}"
    ) missingRecoveryTopics
    ++ map (
      link: "Public-service recovery matrix is missing required link: ${link}"
    ) missingRecoveryLinks;

  failureReport = pkgs.writeText "public-service-recovery-drill-failures" (
    lib.concatStringsSep "\n" failures
  );
in
pkgs.runCommand "public-service-recovery-drill"
  {
    inherit failureReport;
  }
  ''
    if [ -s "$failureReport" ]; then
      echo "Public-service recovery-readiness checks failed:" >&2
      cat "$failureReport" >&2
      exit 1
    fi

    touch "$out"
  ''
