{ pkgs }:
pkgs.runCommand "reboot-required-smoke" { } ''
  test -f ${../modules/features/reboot-required.nix}
  touch "$out"
''
