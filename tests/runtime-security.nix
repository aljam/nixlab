# Runtime security invariants for SOPS secrets, listening services, and
# firewall exceptions.
#
# This test uses an ephemeral age key and encrypted test secret. It does not
# require or expose production secret material.
{
  pkgs,
  sopsModule,
}:

let
  inherit (pkgs) lib;

  haproxyAddress = "192.168.1.1";

  sopsKeys = pkgs.runCommand "sops-test-keys"
    {
      nativeBuildInputs = [
        pkgs.age
        pkgs.gnugrep
        pkgs.gawk
      ];
    }
    ''
      mkdir -p "$out"

      age-keygen -o "$out/key.txt" 2>&1 \
        | grep -i 'public key:' \
        | awk '{print $3}' > "$out/recipient"

      test -s "$out/recipient"
    '';

  sopsSecret = pkgs.runCommand "sops-test-secret.yaml"
    {
      nativeBuildInputs = [ pkgs.sops ];
    }
    ''
      recipient="$(cat ${sopsKeys}/recipient)"

      printf 'runtime-security-test-secret\n' > plaintext

      SOPS_AGE_RECIPIENTS="$recipient" \
        sops -e plaintext > "$out"
    '';
in
pkgs.testers.nixosTest {
  name = "runtime-security";

  nodes.machine = { pkgs, ... }: {
    imports = [ sopsModule ];

    networking.firewall.enable = true;
    networking.nftables.enable = true;

    networking.firewall.extraInputRules = ''
      ip saddr ${haproxyAddress} tcp dport 8222 accept comment "HAProxy service backend"
    '';

    sops.age.keyFile = "${sopsKeys}/key.txt";

    sops.secrets."runtime-security-test" = {
      sopsFile = "${sopsSecret}";
      owner = "app";
      group = "app";
      mode = "0400";
    };

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
    machine.wait_for_file("/run/secrets/runtime-security-test")

    with subtest("SOPS secret has the declared runtime identity and permissions"):
        metadata = machine.succeed(
            "stat -c '%U %G %a' /run/secrets/runtime-security-test"
        ).strip()

        if metadata != "app app 400":
            raise Exception(
                f"Unexpected secret ownership or mode: {metadata}"
            )

        machine.succeed(
            "grep -q 'runtime-security-test-secret' /run/secrets/runtime-security-test"
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

        if f"ip saddr {haproxyAddress}" not in backend_rules[0]:
            raise Exception("The backend firewall exception is not scoped to HAProxy")
  '';
}
