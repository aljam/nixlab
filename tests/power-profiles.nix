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
      "power-profiles"
      "enable"
    ] false value
  ) hosts;

  supportedProfiles = [
    "performance"
    "balanced"
    "power-saver"
  ];

  check = condition: message: if condition then true else throw message;

  checks = lib.concatMap (
    hostname:
    let
      cfg = hosts.${hostname}.config.modules.features.power-profiles;
    in
    [
      (check (lib.elem cfg.preferredProfile supportedProfiles) "${hostname} has an unsupported power profile: ${cfg.preferredProfile}")
    ]
  ) (builtins.attrNames enabledHosts);
in
pkgs.runCommand "power-profiles-config-check" { } ''
  touch $out
''
