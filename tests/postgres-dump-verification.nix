{ pkgs }:
pkgs.runCommand "postgres-dump-verification-config-smoke"
  { }
  ''
    test -f ${../modules/features/postgres.nix}
    touch "$out"
  ''
