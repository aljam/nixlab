{ lib, ... }:
{
  name = "host-baseline";

  nodes.machine =
    { ... }:
    {
      imports = [
        ../modules/features/host-baseline.nix
        ../modules/features/node-exporter.nix
      ];

      modules.features.host-baseline.enable = true;

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("nixlab-host-baseline.service")
    machine.wait_for_file("/var/lib/node-exporter/textfile/nixlab-host-baseline.prom")

    with subtest("SSH hardening remains healthy"):
        machine.succeed(
            "grep -q 'nixlab_host_baseline_ssh_hardening_ok 1' /var/lib/node-exporter/textfile/nixlab-host-baseline.prom"
        )

    with subtest("baseline metrics are exported"):
        machine.succeed(
            "grep -q 'nixlab_host_baseline_failed_system_units' /var/lib/node-exporter/textfile/nixlab-host-baseline.prom"
        )
        machine.succeed(
            "grep -q 'nixlab_host_baseline_journal_usage_bytes' /var/lib/node-exporter/textfile/nixlab-host-baseline.prom"
        )
  '';
}
