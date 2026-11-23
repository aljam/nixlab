{
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;

  enabledHosts = lib.filterAttrs (
    _: value:
    lib.attrByPath [
      "config"
      "modules"
      "features"
      "disk-health"
      "enable"
    ] false value
  ) hosts;
in
pkgs.runCommand "disk-health-config-check" { } ''
  ${lib.concatStringsSep "\\n" (
    lib.mapAttrsToList (
      hostname: _:
      ''
        echo "${hostname} enables disk-health monitoring."
      ''
    ) enabledHosts
  )}

  touch $out
''
