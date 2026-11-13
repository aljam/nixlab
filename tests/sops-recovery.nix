{ lib, ... }:
{
  name = "sops-recovery";

  nodes.machine =
    { ... }:
    {
      imports = [ ../modules/features/sops.nix ];

      sops = {
        age.keyFile = "/var/lib/sops/age/keys.txt";

        secrets = {
          host-secret = {
            file = ./fixtures/host-secret.yaml;
            owner = "root";
            group = "root";
            mode = "0400";
          };

          unrelated-secret = {
            file = ./fixtures/unrelated-secret.yaml;
            owner = "root";
            group = "root";
            mode = "0400";
          };
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("sops-nix.service")

    with subtest("the authorized host secret is decrypted"):
        machine.succeed(
            "test -s /run/secrets/host-secret"
        )

    with subtest("an unrelated host secret is not decrypted"):
        machine.fail(
            "test -e /run/secrets/unrelated-secret"
        )

    with subtest("the host cannot decrypt an unrelated secret"):
        machine.fail(
            "sops --decrypt ./fixtures/unrelated-secret.yaml >/dev/null"
        )
  '';
}
