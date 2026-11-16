{
  pkgs,
  deployScript,
  deployHosts,
}:

let
  inherit (pkgs) lib;

  validRev = "0123456789abcdef0123456789abcdef01234567";
  otherRev = "fedcba9876543210fedcba9876543210fedcba98";
  hostList = lib.concatStringsSep " " deployHosts;
in
pkgs.runCommand "deploy-behavior" { } ''
  DEPLOY_SCRIPT=${deployScript} DEPLOY_HOSTS=${hostList} VALID_REV=${validRev} OTHER_REV=${otherRev} bash ${./fixtures/deploy/run.sh}
  touch $out
''
