{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.modules.features.alert-test;

  alertTestScript = pkgs.writers.writeBash "nixlab-alert-test" ''
    set -euo pipefail

    severity="${cfg.severity}"
    fingerprint=$(printf 'nixlab-alert-test-%s' "$severity")

    payload=$(jq -n \\
      --arg severity "$severity" \\
      --arg fingerprint "$fingerprint" \\
      '[{
        startsAt: (now | todate),
        endsAt: "",
        generatorURL: "https://nixlab.local/alert-test",
        labels: {
          alertname: "NixLabAlertDeliveryTest",
          severity: $severity,
          instance: "alert-test"
        },
        annotations: {
          summary: "NixLab alert delivery test",
          description: "Controlled test alert; safe to resolve."
        }
      }]')

    curl -fsS \\
      -H 'Content-Type: application/json' \\
      -d "$payload" \\
      http://127.0.0.1:9093/api/v2/alerts

    echo "Submitted $severity alert delivery test with fingerprint $fingerprint."
  '';

  alertResolveScript = pkgs.writers.writeBash "nixlab-alert-resolve" ''
    set -euo pipefail

    severity="${cfg.severity}"
    fingerprint=$(printf 'nixlab-alert-test-%s' "$severity")

    payload=$(jq -n \\
      --arg severity "$severity" \\
      --arg fingerprint "$fingerprint" \\
      '[{
        startsAt: (now | todate),
        endsAt: (now | todate),
        generatorURL: "https://nixlab.local/alert-test",
        labels: {
          alertname: "NixLabAlertDeliveryTest",
          severity: $severity,
          instance: "alert-test"
        },
        annotations: {
          summary: "NixLab alert recovery test",
          description: "Controlled test alert resolved."
        }
      }]')

    curl -fsS \\
      -H 'Content-Type: application/json' \\
      -d "$payload" \\
      http://127.0.0.1:9093/api/v2/alerts

    echo "Resolved $severity alert delivery test with fingerprint $fingerprint."
  '';
in
{
  options.modules.features.alert-test = {
    enable = mkEnableOption "controlled alert delivery validation";

    severity = mkOption {
      type = types.enum [
        "warning"
        "critical"
      ];
      default = "warning";
      description = "Severity of the controlled alert delivery test.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "nixlab-alert-test" "${alertTestScript}")
      (pkgs.writeShellScriptBin "nixlab-alert-resolve" "${alertResolveScript}")
    ];
  };
}
