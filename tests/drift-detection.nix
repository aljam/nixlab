{ lib, ... }:
{
  name = "drift-detection";

  nodes.machine =
    { ... }:
    {
      imports = [ ../modules/features/drift-monitoring.nix ];

      modules.features.node-exporter.textfileDirectory = "/var/lib/node-exporter/textfile";

      modules.features.drift-monitoring = {
        enable = true;
        expectedRevision = "expected-revision";
        criticalUnits = [ "sshd.service" ];
        allowedTcpPorts = [ 22 ];
        allowedUdpPorts = [ ];
      };

      services.openssh.enable = true;
    };

  testScript = ''
    machine.wait_for_unit("nixlab-drift-metrics.service")
    machine.wait_for_file("/var/lib/node-exporter/textfile/nixlab-drift.prom")

    machine.succeed(
      "grep -q 'nixlab_drift_revision_mismatch 1' /var/lib/node-exporter/textfile/nixlab-drift.prom"
    )

    machine.succeed(
      "systemctl stop sshd.service"
    )

    machine.execute(
      "systemctl start nixlab-drift-metrics.service"
    )

    machine.succeed(
      "grep -q 'nixlab_drift_failed_critical_units 1' /var/lib/node-exporter/textfile/nixlab-drift.prom"
    )

    machine.succeed(
      "systemctl start sshd.service"
    )
  '';
}
