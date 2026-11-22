{
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;

  enabledHosts = lib.filterAttrs (
    _: value:
    lib.attrByPath
      [
        "config"
        "modules"
        "features"
        "disk-health"
        "enable"
      ]
      false
      value
  ) hosts;
in
pkgs.runCommand "disk-health-config-check" { } ''
  ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      hostname: value:
      let
        devices = value.config.modules.features.disk-health.devices;
      in
      lib.optionalString (devices == [ ]) ''
        echo "ERROR: ${hostname} enables disk-health but configures no devices." >&2
        exit 1
      ''
    ) enabledHosts
  )}

  touch $out
''
