# End-to-end regression test for the fleet's firewall isolation.
#
# Four machines on one LAN, exercising the two rules that
# modules/features/reverse-proxy-backends.nix generates:
#
#   * only the HAProxy gateway may reach a service backend port
#   * only the Prometheus server may reach node_exporter
#
# The cheap eval-only counterpart is tests/nftables-input-rules.nix. This test
# is what actually catches a rule that is syntactically fine but too broad —
# for example a bare `accept`, which would let `attacker` through below.
{ lib, ... }:

let
  backendPort = 3000;
  exporterPort = 9100;

  # Anything that answers on a backend port. Deliberately not a real service
  # module: the subject under test is the firewall, not Grafana.
  backendApp =
    pkgs:
    {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString backendPort} --bind 0.0.0.0";
        DynamicUser = true;
      };
    };

  # A plain LAN client with no special privileges.
  client = {
    networking.firewall.enable = true;
    networking.nftables.enable = true;
  };
in
{
  name = "firewall-isolation";

  nodes = {
    backend =
      { nodes, pkgs, ... }:
      {
        imports = [
          ../modules/features/networking-options.nix
          ../modules/features/reverse-proxy-backends.nix
          ../modules/features/node-exporter.nix
        ];

        networking.firewall.enable = true;
        networking.nftables.enable = true;

        # Only the two entries the rules under test consume, wired to the
        # addresses the test framework handed the other machines.
        networking.fleet = lib.mkForce {
          proxy.ip = nodes.gateway.networking.primaryIPAddress;
          r730xd.ip = nodes.prometheus.networking.primaryIPAddress;
        };

        networking.proxyBackendPorts = [ backendPort ];

        systemd.services.backend-app = backendApp pkgs;
      };

    gateway = { ... }: client;
    prometheus = { ... }: client;
    attacker = { ... }: client;
  };

  testScript = ''
    start_all()

    backend.wait_for_unit("nftables.service")
    backend.wait_for_unit("backend-app.service")
    backend.wait_for_open_port(${toString backendPort})
    backend.wait_for_unit("prometheus-node-exporter.service")
    backend.wait_for_open_port(${toString exporterPort})

    for machine in [gateway, prometheus, attacker]:
        machine.wait_for_unit("multi-user.target")

    # Reach the backend by name: the test driver puts every machine's vlan1
    # address in /etc/hosts, so traffic leaves over the LAN interface and the
    # source address is the one the firewall rules are written against. Using
    # the machine's own `hostname -I` would pick up QEMU's 10.0.2.x NAT address
    # on eth0 instead.
    backend_url = "http://backend:${toString backendPort}/"
    metrics_url = "http://backend:${toString exporterPort}/metrics"

    def reachable(machine, url):
        machine.succeed(f"curl -fsS --max-time 10 -o /dev/null {url}")

    def unreachable(machine, url):
        machine.fail(f"curl -o /dev/null -fsS --max-time 10 {url}")

    with subtest("only the gateway reaches a backend port"):
        reachable(gateway, backend_url)
        unreachable(attacker, backend_url)
        unreachable(prometheus, backend_url)

    with subtest("only the prometheus server reaches node_exporter"):
        reachable(prometheus, metrics_url)
        unreachable(attacker, metrics_url)
        unreachable(gateway, metrics_url)

    with subtest("the input-allow chain holds no unqualified verdict"):
        rules = backend.succeed("nft -a list chain inet nixos-fw input-allow")
        for line in rules.splitlines():
            stripped = line.strip()
            if stripped.startswith(("accept", "drop", "reject")):
                raise Exception(f"unqualified verdict in input-allow: {stripped}")
  '';
}
