{ pkgs, ... }:
pkgs.testers.nixosTest {
  name = "alert-delivery";

  nodes.machine =
    { ... }:
    {
      imports = [
        ../modules/features/alert-test.nix
      ];

      modules.features.alert-test.enable = true;

      services.prometheus.alertmanager = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9093;

        configuration = {
          route = {
            group_by = [ "alertname" ];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";
            receiver = "ntfy";
          };

          receivers = [
            {
              name = "ntfy";
              webhook_configs = [
                {
                  url = "http://127.0.0.1:8080/test";
                  send_resolved = true;
                }
              ];
            }
          ];
        };
      };

      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "http://127.0.0.1:8080";
          listen-http = "127.0.0.1:8080";
          visitor-request-limit-burst = 100;
          visitor-request-limit-replenish = "1s";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("alertmanager.service")
    machine.wait_for_unit("ntfy-sh.service")

    with subtest("a warning test alert reaches the local Ntfy receiver"):
        machine.succeed("nixlab-alert-test --severity warning")
        machine.wait_until_succeeds(
            "curl -fsS --max-time 10 'http://127.0.0.1:8080/test/json?poll=1' | grep -q 'NixLabAlertDeliveryTest'",
            timeout=60,
        )

    with subtest("resolving the test alert produces a recovery notification"):
        machine.succeed("nixlab-alert-resolve --severity warning")
        machine.wait_until_succeeds(
            "sleep 5; curl -fsS --max-time 10 'http://127.0.0.1:8080/test/json?poll=1&since=1m' | grep -q 'resolved'",
            timeout=60,
        )
  '';
}
