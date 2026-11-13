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
                }
              ];
            }
          ];
        };
      };

      services.ntfy-sh = {
        enable = true;
        settings = {
          listen-http = "127.0.0.1:8080";
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
            "curl -fsS http://127.0.0.1:8080/test | grep -q 'NixLabAlertDeliveryTest'",
            timeout=60,
        )

    with subtest("resolving the test alert produces a recovery notification"):
        machine.succeed("nixlab-alert-resolve --severity warning")
        machine.wait_until_succeeds(
            "curl -fsS http://127.0.0.1:8080/test | grep -q 'resolved'",
            timeout=60,
        )
  '';
}
