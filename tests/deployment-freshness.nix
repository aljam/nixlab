{ pkgs }:
pkgs.runCommand "deployment-freshness-smoke" { } ''
  test -f ${../modules/features/drift-monitoring.nix}
  touch "$out"
''
