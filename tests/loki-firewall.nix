# End-to-end regression test for direct LAN access to Loki.
#
# The pfSense Tailscale ingress rules control remote access, but they do not
# protect Loki from clients already on the LAN. This test validates the
# r730xd host firewall as a second layer of control.
#
# The service under test is a stand-in HTTP server on Loki's TCP/3100 port:
# the subject is the firewall rule, not Loki itself.
{ lib, ... }:

let
  lokiPort = 3100;

  client = {
    networking.firewall.enable = true;
    networking.nftables.enable = true;
  };

  lokiPortApp = pkgs: {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString lokiPort} --bind 0.0.0.0";
      DynamicUser = true;
    };
  };
in
{
  name = "loki-lan-firewall";

  nodes = {
    loki =
      { nodes, pkgs, ... }:
      {
        imports = [
          ../modules/features/networking-options.nix
        ];

        networking.firewall.enable = true;
        networking.nftables.enable = true;

        networking.firewall.extraInputRules = ''
          ip saddr ${nodes.approvedClient.networking.primaryIPAddress} tcp dport ${toString lokiPort} accept comment "Loki approved LAN client"
        '';

        systemd.services.loki-port-app = lokiPortApp pkgs;
      };

    approvedClient = { ... }: client;
    unapprovedClient = { ... }: client;
  };

  testScript = ''
    start_all()

    loki.wait_for_unit("nftables.service", timeout=180)
    loki.wait_for_unit("loki-port-app.service", timeout=180)
    loki.wait_for_open_port(${toString lokiPort}, timeout=180)

    for machine in [approvedClient, unapprovedClient]:
        machine.wait_for_unit("multi-user.target", timeout=300)

    loki_url = f"http://loki:${toString lokiPort}/"

    def reachable(machine, url):
        machine.succeed(f"curl -fsS --max-time 10 -o /dev/null {url}")

    def unreachable(machine, url):
        machine.fail(f"curl -o /dev/null -fsS --max-time 10 {url}")

    with subtest("approved LAN client reaches Loki"):
        reachable(approvedClient, loki_url)

    with subtest("unapproved LAN client cannot reach Loki"):
        unreachable(unapprovedClient, loki_url)

    with subtest("Loki remains locally reachable"):
        loki.succeed(
            "curl -fsS --max-time 10 -o /dev/null "
            f"http://127.0.0.1:${toString lokiPort}/"
        )

    with subtest("Loki rule is source-scoped"):
        rules = loki.succeed("nft -a list chain inet nixos-fw input-allow")
        assert f"tcp dport ${toString lokiPort}" in rules
        assert "ip saddr" in rules

    with subtest("the input-allow chain holds no unqualified verdict"):
        rules = loki.succeed("nft -a list chain inet nixos-fw input-allow")
        for line in rules.splitlines():
            stripped = line.strip()
            if stripped.startswith(("accept", "drop", "reject")):
                raise Exception(f"unqualified verdict in input-allow: {stripped}")
  '';
}
