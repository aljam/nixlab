{ pkgs }:

pkgs.testers.runNixOSTest {
  name = "deployment-freshness";

  nodes.machine =
    { ... }:
    {
      imports = [
        ../modules/features/drift-monitoring.nix
        ../modules/features/systemd-hardening.nix
        ../modules/features/node-exporter.nix
      ];

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
    machine.wait_for_unit("nixlab-drift-metrics.timer")

    machine.succeed("systemctl start nixlab-drift-metrics.service")
    machine.wait_for_file("/var/lib/node-exporter/textfile/nixlab-drift.prom")

    machine.succeed(
      "grep -q 'nixlab_deployment_activation_timestamp_seconds ' /var/lib/node-exporter/textfile/nixlab-drift.prom"
    )

    machine.succeed(
      "grep -q 'nixlab_deployment_age_seconds ' /var/lib/node-exporter/textfile/nixlab-drift.prom"
    )

    machine.succeed(
      "grep -Eq 'nixlab_deployment_generation\\{generation=\"[0-9]+\"\\} 1' /var/lib/node-exporter/textfile/nixlab-drift.prom"
    )
  '';
}
