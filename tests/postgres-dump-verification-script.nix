{ pkgs }:
pkgs.runCommand "postgres-dump-verification-script-smoke"
  {
    nativeBuildInputs = [ pkgs.postgresql ];
  }
  ''
    pg_restore --version >/dev/null
    touch "$out"
  ''
