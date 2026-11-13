{ lib, pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in
pkgs.runCommand "sops-recovery-check"
  {
    nativeBuildInputs = [ pythonEnv ];
  }
  ''
    ${pythonEnv}/bin/python ${./sops-recovery-check.py} ${../.sops.yaml} ${../secrets}
    touch $out
  ''
