{ ... }:
{
  name = "tailscale-health";

  nodes.machine =
    { ... }:
    {
      imports = [
        ../modules/features/tailscale-health.nix
        ../modules/features/systemd-hardening.nix
      ];

      services.tailscale.enable = true;
      modules.features.tailscale-health.enable = true;
    };

  testScript = ''
    start_all()

    with subtest("Tailscale health service is configured"):
        machine.succeed("systemctl cat nixlab-tailscale-health.service")
        machine.succeed("systemctl cat nixlab-tailscale-health.timer")

    with subtest("Tailscale health metrics are collected every minute"):
        machine.succeed(
            "systemctl show nixlab-tailscale-health.timer --property=OnCalendar | grep -q 'OnCalendar=*-*-* *:*:00'"
        )

    with subtest("Tailscale health service writes to the node-exporter textfile directory"):
        machine.succeed(
            "systemctl cat nixlab-tailscale-health.service | grep -q '/var/lib/node-exporter/textfile/tailscale.prom'"
        )
  '';
}
