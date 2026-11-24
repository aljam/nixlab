{
  pkgs,
  hosts,
}:
let
  inherit (pkgs) lib;

  replicationHosts = lib.filterAttrs (
    _: value:
    lib.attrByPath [
      "config"
      "modules"
      "features"
      "restic-replication"
      "enable"
    ] false value
  ) hosts;

  check = condition: message: if condition then true else throw message;

  destinationChecks = lib.concatMap (
    hostname:
    lib.mapAttrsToList (
      name: job:
      check (
        job.destinationRepository != null
      ) "${hostname} enables Restic replication job ${name} without a destinationRepository."
    ) (lib.attrByPath [
      "config"
      "modules"
      "features"
      "restic-replication"
      "jobs"
    ] { } replicationHosts.${hostname})
  ) (lib.attrNames replicationHosts);

  checks = [
    (check (replicationHosts == { }) "Restic replication must remain disabled in this scaffolding commit.")
  ] ++ destinationChecks;
in
pkgs.runCommand "restic-replication-config-check"
  { }
  ''
    touch $out
  ''
