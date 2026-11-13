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

  curl = lib.getExe pkgs.curl;
  jq = lib.getExe pkgs.jq;

  alertTestScript = pkgs.writers.writeBash "nixlab-alert-test" ''
    set -euo pipefail

    severity="${cfg.severity}"
    fingerprint=$(printf 'nixlab-alert-test-%s' "$severity")

    payload=$(${jq} -n --arg severity "$severity" --arg fingerprint "$fingerprint" '[{"startsAt":(now|todate),"generatorURL":"https://nixlab.local/alert-test","labels":{"alertname":"NixLabAlertDeliveryTest","severity":$severity,"instance":"alert-test"},"annotations":{"summary":"NixLab alert delivery test","description":"Controlled test alert; safe to resolve."}}]')

    ${curl} -fsS -H 'Content-Type: application/json' -d "$payload" http://127.0.0.1:9093/api/v2/alerts

    echo "Submitted $severity alert delivery test with fingerprint $fingerprint."
  '';

  alertResolveScript = pkgs.writers.writeBash "nixlab-alert-resolve" ''
    set -euo pipefail

    severity="${cfg.severity}"
    fingerprint=$(printf 'nixlab-alert-test-%s' "$severity")

    active_alerts=$(${curl} -fsS 'http://127.0.0.1:9093/api/v2/alerts?active=true')
    resolved_at=$(date -u +'%Y-%m-%dT%H:%M:%S.%3NZ')

    payload=$(printf '%s' "$active_alerts" | ${jq} -c --arg severity "$severity" --arg resolved_at "$resolved_at" '
      map(
        select(
          .labels.alertname == "NixLabAlertDeliveryTest"
          and .labels.severity == $severity
        )
        | .endsAt = $resolved_at
        | .annotations = {
            summary: "NixLab alert recovery test",
            description: "Controlled test alert resolved."
          }
      )
    ')

    if [[ "$(printf '%s' "$payload" | ${jq} 'length')" -eq 0 ]]; then
      echo "No active NixLabAlertDeliveryTest alert with severity $severity" >&2
      exit 1
    fi

    ${curl} -fsS -H 'Content-Type: application/json' -d "$payload" http://127.0.0.1:9093/api/v2/alerts

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
      pkgs.curl
      pkgs.jq
      (pkgs.writeShellScriptBin "nixlab-alert-test" "${alertTestScript}")
      (pkgs.writeShellScriptBin "nixlab-alert-resolve" "${alertResolveScript}")
    ];
  };
}
