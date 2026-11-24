{ pkgs }:
pkgs.testers.nixosTest {
  name = "nix-gc-observability";

  nodes.monitor = { lib, ... }: {
    imports = [
      ../modules/features/networking-options.nix
      ../modules/features/systemd-hardening.nix
      ../modules/features/prometheus-server.nix
    ];
    options.networking.servicesBindAddress = lib.mkOption {
      type = lib.types.str;
    };
    config = {
      networking.servicesBindAddress = "127.0.0.1";
      networking.fleet = lib.mkForce {
        r730xd.ip = "127.0.0.1";
        r820.ip = "127.0.0.1";
      };
      modules.features.prometheus-server.enablePublicEndpointProbes = false;
    };
  };

  testScript = ''
    import json

    start_all()
    monitor.wait_for_unit("prometheus.service", timeout=180)
    monitor.wait_until_succeeds(
        "curl -fsS --max-time 10 http://127.0.0.1:9090/-/ready",
        timeout=60,
    )

    with subtest("Nix GC rules are provisioned with actionable annotations"):
        payload = json.loads(monitor.succeed(
            "curl -fsS --max-time 10 http://127.0.0.1:9090/api/v1/rules"
        ))
        assert payload.get("status") == "success", payload
        groups = [g for g in payload["data"]["groups"] if g["name"] == "nix-gc"]
        assert len(groups) == 1, groups
        expected = {
            "NixGarbageCollectionFailed": ("warning", 900),
            "NixGarbageCollectionStale": ("warning", 3600),
            "NixStoreLowSpace": ("warning", 900),
            "NixStoreCriticalSpace": ("critical", 300),
        }
        rules = groups[0]["rules"]
        assert len(rules) == len(expected), rules
        assert {r["name"] for r in rules} == set(expected), rules
        for rule in rules:
            severity, duration = expected[rule["name"]]
            assert rule["type"] == "alerting", rule
            assert rule["labels"]["severity"] == severity, rule
            assert rule["duration"] == duration, rule
            for key in ("summary", "description", "runbook_url"):
                value = rule.get("annotations", {}).get(key)
                assert isinstance(value, str) and value.strip(), (rule, key)
  '';
}
