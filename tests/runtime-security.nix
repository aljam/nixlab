# Runtime security invariants for SOPS secrets, listening services, and
# firewall exceptions.
#
# This test generates an ephemeral age key and SOPS-encrypted secret inside
# the VM. It does not require or expose production secret material.
{
  pkgs,
}:

let
  haproxyAddress = "192.168.1.1";
in
pkgs.testers.nixosTest {
  name = "runtime-security";

  nodes.machine = { pkgs, ... }: {
    networking.firewall.enable = true;
    networking.nftables.enable = true;

    networking.firewall.extraInputRules = ''
      ip saddr ${haproxyAddress} tcp dport 8222 accept comment "HAProxy service backend"
    '';

    users.users.app = {
      isSystemUser = true;
      group = "app";
    };

    users.groups.app = { };

    systemd.services.inventory-http = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8080 --bind 127.0.0.1";
        DynamicUser = true;
      };
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("inventory-http.service")

    with subtest("SOPS encryption and decryption preserve runtime permissions"):
        machine.succeed("age-keygen -o /tmp/sops-test-key >/dev/null 2>&1")

        recipient = machine.succeed("age-keygen -y /tmp/sops-test-key").strip()

        machine.succeed(
            "printf 'runtime-security-test-secret\\n' | "
            f"SOPS_AGE_RECIPIENTS='{recipient}' "
            "sops -e /dev/stdin > /tmp/runtime-security-secret.yaml"
        )

        machine.succeed(
            "install -D -o app -g app -m 0400 "
            "/tmp/runtime-security-secret.yaml /run/secrets/runtime-security-test"
        )

        decrypted = machine.succeed(
            "SOPS_AGE_KEY_FILE=/tmp/sops-test-key "
            "sops -d /run/secrets/runtime-security-test"
        ).strip()

        if decrypted != "runtime-security-test-secret":
            raise Exception("SOPS did not preserve the test secret")

        metadata = machine.succeed(
            "stat -c '%U %G %a' /run/secrets/runtime-security-test"
        ).strip()

        if metadata != "app app 400":
            raise Exception(
                f"Unexpected secret ownership or mode: {metadata}"
            )

    with subtest("the declared service listens only on loopback"):
        listeners = machine.succeed("ss -ltn")

        if "127.0.0.1:8080" not in listeners:
            raise Exception("The inventory HTTP service is not listening on loopback")

    with subtest("no service listens on every interface"):
        listeners = machine.succeed("ss -ltn")

        for line in listeners.splitlines():
            fields = line.split()
            if len(fields) < 4:
                continue

            local_address = fields[3]
            address = local_address.rsplit(":", 1)[0]

            if address in ["0.0.0.0", "::"]:
                raise Exception(f"Wildcard listener detected: {line}")

    with subtest("the firewall has exactly one HAProxy-scoped backend exception"):
        ruleset = machine.succeed("nft list ruleset")
        backend_rules = [
            line.strip()
            for line in ruleset.splitlines()
            if "tcp dport 8222 accept" in line
        ]

        if len(backend_rules) != 1:
            raise Exception(
                f"Expected one backend firewall exception, found {len(backend_rules)}"
            )

        if "ip saddr ${haproxyAddress}" not in backend_rules[0]:
            raise Exception("The backend firewall exception is not scoped to HAProxy")
  '';
}
