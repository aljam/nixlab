{ pkgs }:

pkgs.testers.nixosTest {
  name = "sops-rotation";

  nodes.server = { lib, ... }: {
    imports = [
      ../modules/features/sops.nix
    ];

    sops.secrets.rotation-test = {
      sopsFile = ./fixtures/sops-rotation.yaml;
      owner = "rotation-test";
      group = "rotation-test";
      mode = "0400";
      restartUnits = [ "rotation-test.service" ];
    };

    users.groups.rotation-test = { };

    users.users.rotation-test = {
      isSystemUser = true;
      group = "rotation-test";
    };

    systemd.services.rotation-test = {
      description = "SOPS rotation test service";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];

      serviceConfig = {
        Type = "simple";
        User = "rotation-test";
        Group = "rotation-test";
        ExecStart = pkgs.writeShellScript "rotation-test-service" ''
          while true; do
            value="$(cat /run/secrets/rotation-test)"
            printf 'HTTP/1.1 200 OK\r\nContent-Length: %s\r\n\r\n%s' \
              "$(printf %s "$value" | wc -c)" "$value" \
              | nc -l -p 8080 -s 127.0.0.1
          done
        '';
        Restart = "always";
      };
    };
  };

  testScript = ''
    server.start()
    server.wait_for_unit("sops-nix.service", timeout=120)
    server.wait_for_unit("rotation-test.service", timeout=120)
    server.wait_for_open_port(8080, "127.0.0.1", timeout=120)

    with subtest("the initial secret value is served"):
        server.succeed(
            "curl -fsS --max-time 10 http://127.0.0.1:8080 | grep -q initial-value"
        )

    with subtest("the secret remains owner-only"):
        server.succeed(
            "test \( $(stat -c %a /run/secrets/rotation-test) \) -eq 400"
        )
        server.succeed(
            "test \( $(stat -c %U /run/secrets/rotation-test) \) = rotation-test"
        )

    with subtest("changing the secret restarts the consumer"):
        server.succeed(
            "printf rotated-value > /run/secrets/rotation-test"
        )
        server.wait_until_succeeds(
            "curl -fsS --max-time 10 http://127.0.0.1:8080 | grep -q rotated-value",
            timeout=120,
        )
  '';
}
