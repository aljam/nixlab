{ pkgs, ... }:
{
  name = "storage-capacity";

  nodes.machine =
    { ... }:
    {
      services.prometheus = {
        enable = true;
        port = 9090;
        listenAddress = "127.0.0.1";
        ruleFiles = [
          ../modules/features/prometheus/rules/storage-capacity-rules.yml
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

    assert "StorageCapacityCritical" in rules, rules
    assert "StorageCapacityForecastExhaustion" in rules, rules
  '';
}
