# Runtime isolation tests for administrative services and PostgreSQL.
#
# The firewall-isolation test proves that only HAProxy can reach an allowed
# backend port. These tests cover the other half of the exposure model:
# administrative and database services must not become reachable merely because
# they are listening.
#
# Import with:
#   import ./runtime-isolation.nix { pkgs = ...; test = "admin-isolation"; }
#   import ./runtime-isolation.nix { pkgs = ...; test = "postgresql-auth"; }
{
  pkgs,
  test ? "admin-isolation",
}:

let
  inherit (pkgs) lib;

  httpServer =
    pkgs: port:
    {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString port} --bind 0.0.0.0";
        DynamicUser = true;
      };
    };

  tests = {
    # Prove that pgAdmin and Shoko stand-ins remain unreachable from other LAN
    # machines even if their application processes listen on every interface.
    # The allowed backend port remains reachable only by the HAProxy gateway.
    admin-isolation = pkgs.testers.nixosTest {
      name = "admin-isolation";

      nodes = {
        backend =
          { nodes, pkgs, ... }:
          {
            imports = [
              ../modules/features/networking-options.nix
              ../modules/features/reverse-proxy-backends.nix
            ];

            networking.firewall.enable = true;
            networking.nftables.enable = true;

            networking.fleet = lib.mkForce {
              proxy.ip = nodes.gateway.networking.primaryIPAddress;
              r730xd.ip = nodes.attacker.networking.primaryIPAddress;
            };

            networking.proxyBackendPorts = [ 3000 ];

            systemd.services = {
              public-backend = httpServer pkgs 3000;
              pgadmin-standin = httpServer pkgs 5050;
              shoko-standin = httpServer pkgs 8111;
            };
          };

        gateway = { ... }: {
          networking.firewall.enable = true;
          networking.nftables.enable = true;
        };

        attacker = { ... }: {
          networking.firewall.enable = true;
          networking.nftables.enable = true;
        };
      };

      testScript = ''
        start_all()

        backend.wait_for_unit("nftables.service")
        backend.wait_for_unit("public-backend.service")
        backend.wait_for_unit("pgadmin-standin.service")
        backend.wait_for_unit("shoko-standin.service")

        for machine in [gateway, attacker]:
            machine.wait_for_unit("multi-user.target")

        public_url = "http://backend:3000/"
        pgadmin_url = "http://backend:5050/"
        shoko_url = "http://backend:8111/"

        with subtest("only the gateway reaches the allowed backend"):
            gateway.succeed(f"curl -fsS --max-time 10 -o /dev/null {public_url}")
            attacker.fail(f"curl -o /dev/null -fsS --max-time 10 {public_url}")

        with subtest("pgAdmin remains unreachable from other LAN hosts"):
            gateway.fail(f"curl -o /dev/null -fsS --max-time 10 {pgadmin_url}")
            attacker.fail(f"curl -o /dev/null -fsS --max-time 10 {pgadmin_url}")

        with subtest("Shoko remains unreachable from other LAN hosts"):
            gateway.fail(f"curl -o /dev/null -fsS --max-time 10 {shoko_url}")
            attacker.fail(f"curl -o /dev/null -fsS --max-time 10 {shoko_url}")
      '';
    };

    # Prove that PostgreSQL TCP authentication remains limited to an explicit
    # database/user pair and rejects an unknown role.
    postgresql-auth = pkgs.testers.nixosTest {
      name = "postgresql-auth";

      nodes = {
        database = { lib, pkgs, ... }: {
          services.postgresql = {
            enable = true;
            enableTCPIP = true;

            settings = {
              listen_addresses = lib.mkForce "127.0.0.1";
              password_encryption = "scram-sha-256";
            };

            authentication = ''
              local all all peer

              host testdb testuser 127.0.0.1/32 scram-sha-256
            '';

            initialScript = pkgs.writeText "postgresql-auth-test-init.sql" ''
              CREATE USER testuser WITH PASSWORD 'testpass';
              CREATE DATABASE testdb OWNER testuser;
            '';
          };
        };
      };

      testScript = ''
        database.start()
        database.wait_for_unit("postgresql.service")

        with subtest("the configured database user can connect over TCP"):
            database.succeed(
                "PGPASSWORD=testpass psql -h 127.0.0.1 -U testuser -d testdb -c 'SELECT 1' >&2"
            )

        with subtest("an unknown database role cannot connect over TCP"):
            database.fail(
                "PGPASSWORD=testpass psql -h 127.0.0.1 -U unknown -d testdb -c 'SELECT 1' >&2"
            )

        with subtest("PostgreSQL authentication contains no broad host/all/all rule"):
            config = database.succeed("cat /etc/postgresql/config/pg_hba.conf")
            if "host all all" in config:
                raise Exception("PostgreSQL contains a broad host/all/all rule")
      '';
    };
  };
in
assert lib.hasAttr test tests;
tests.${test}
