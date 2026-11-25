{ pkgs, ... }:
{
  name = "upstream-network";

  nodes.machine =
    { ... }:
    {
      services.prometheus = {
        enable = true;
        port = 9090;
        listenAddress = "127.0.0.1";
        ruleFiles = [
          ../modules/features/prometheus/rules/upstream-network-rules.yml
        ];
        globalConfig.evaluation_interval = "1s";
      };

      environment.systemPackages = [ pkgs.jq ];
    };

  testScript = ''
    machine.wait_for_unit("prometheus.service")
    machine.wait_for_open_port(9090)

    rules = machine.wait_until_succeeds(
      "curl -fsS http://127.0.0.1:9090/api/v1/rules"
      " | jq -r '.data.groups[].rules[].name'"
    )

    assert "UpstreamDNSUnavailable" in rules, rules
    assert "UpstreamDNSLatencyHigh" in rules, rules
    assert "DHCPServiceUnavailable" in rules, rules
    assert "DHCPLeasePoolExhaustion" in rules, rules
  '';
}
