{ ... }:
{
  name = "tailscale-observability-vm";

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

    with subtest("Tailscale health service runs and writes metrics"):
        machine.succeed("systemctl start nixlab-tailscale-health.service")
        machine.succeed("test -s /var/lib/node-exporter/textfile/tailscale.prom")

    with subtest("Tailscale metrics expose at least one tailscaled_ metric"):
        machine.succeed("grep -q '^tailscaled_' /var/lib/node-exporter/textfile/tailscale.prom")

    with subtest("Tailscale metric names for debugging"):
        machine.execute("grep '^tailscaled_' /var/lib/node-exporter/textfile/tailscale.prom")
  '';
}
