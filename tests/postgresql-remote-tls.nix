# Runtime check that remote PostgreSQL authentication requires TLS.
{
  pkgs,
}:

pkgs.testers.nixosTest {
  name = "postgresql-remote-tls";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/features/networking-options.nix
      ../../modules/features/postgres.nix
      ../../modules/features/security-policy.nix
    ];

    networking.firewall.enable = true;
    networking.nftables.enable = true;

    networking.fleet = {
      r730xd.ip = "192.168.1.2";
    };

    sops.secrets.pgadmin_password = {
      sopsFile = ../../secrets/database.yaml;
      owner = "pgadmin";
      group = "pgadmin";
      mode = "0400";
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("postgresql.service")

    with subtest("remote PostgreSQL rules require TLS"):
        pg_hba = machine.succeed(
            "cat /var/lib/postgresql/<version>/data/pg_hba.conf"
        )

        for line in pg_hba.splitlines():
            stripped = line.strip()

            if not stripped.startswith("host "):
                continue

            if "127.0.0.1/32" in stripped or "::1/128" in stripped:
                continue

            if not stripped.startswith("hostssl "):
                raise Exception(
                    f"Non-loopback PostgreSQL rule does not require TLS: {stripped}"
                )
  '';
}
