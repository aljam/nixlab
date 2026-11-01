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
#   import ./runtime-isolation.nix { pkgs = ...; test = "postgresql-reachability"; }
{
  pkgs,
  test ? "admin-isolation",
}:

let
  inherit (pkgs) lib;

  # Static addresses keep the generated nftables and PostgreSQL HBA rules
  # aligned with the addresses actually used by the test VMs.
  adminIps = {
    backend = "192.168.1.10";
    gateway = "192.168.1.11";
    attacker = "192.168.1.12";
  };

  postgresIps = {
    database = "192.168.1.20";
    synapse = "192.168.1.21";
    unrelated = "192.168.1.22";
  };

  staticAddress = ip: {
    address = ip;
    prefixLength = 24;
  };

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
        backend = { pkgs, ... }: {
          imports = [
            ../modules/features/networking-options.nix
            ../modules/features/reverse-proxy-backends.nix
          ];

          networking.firewall.enable = true;
          networking.nftables.enable = true;

          networking.interfaces.eth1.ipv4.addresses = [ (staticAddress adminIps.backend) ];

          networking.fleet = lib.mkForce {
            proxy.ip = adminIps.gateway;
            r730xd.ip = adminIps.attacker;
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
          networking.interfaces.eth1.ipv4.addresses = [ (staticAddress adminIps.gateway) ];
        };

        attacker = { ... }: {
          networking.firewall.enable = true;
          networking.nftables.enable = true;
          networking.interfaces.eth1.ipv4.addresses = [ (staticAddress adminIps.attacker) ];
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

        public_url = "http://${adminIps.backend}:3000/"
        pgadmin_url = "http://${adminIps.backend}:5050/"
        shoko_url = "http://${adminIps.backend}:8111/"

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
        database = { lib, ... }: {
          services.postgresql = {
            enable = true;
            enableTCPIP = true;

            ensureDatabases = [ "testdb" ];
            ensureUsers = [
              {
                name = "testuser";
                ensureDBOwnership = true;
              }
            ];

            settings = {
              listen_addresses = lib.mkForce "127.0.0.1";
              password_encryption = "scram-sha-256";
            };

            authentication = ''
              local all all peer

              host testdb testuser 127.0.0.1/32 scram-sha-256
            '';
          };
        };
      };

      testScript = ''
        database.start()
        database.wait_for_unit("postgresql.service")

        # The test role is declaratively created by ensureUsers. Set its
        # password after PostgreSQL is ready so the TCP authentication test
        # does not depend on initial-script ordering.
        database.succeed(
            "sudo -u postgres psql -c \"ALTER ROLE testuser WITH PASSWORD 'testpass';\""
        )

        with subtest("the configured database user can connect over TCP"):
            database.succeed(
                "PGPASSWORD=testpass psql -h 127.0.0.1 -U testuser -d testdb -c 'SELECT 1' >&2"
            )

        with subtest("an unknown database role cannot connect over TCP"):
            database.fail(
                "PGPASSWORD=testpass psql -h 127.0.0.1 -U unknown -d testdb -c 'SELECT 1' >&2"
            )

        with subtest("PostgreSQL authentication contains no broad host/all/all rule"):
            hba_path = database.succeed(
                "sudo -u postgres psql -Atc 'SHOW hba_file'"
            ).strip()
            config = database.succeed(f"cat {hba_path}")
            if "host all all" in config:
                raise Exception("PostgreSQL contains a broad host/all/all rule")
      '';
    };

    # Prove that PostgreSQL is reachable from the explicitly authorized Synapse
    # host, while an unrelated LAN host cannot reach the database port.
    postgresql-reachability = pkgs.testers.nixosTest {
      name = "postgresql-reachability";

      nodes = {
        database = { lib, pkgs, ... }: {
          networking.firewall.enable = true;
          networking.nftables.enable = true;
          networking.interfaces.eth1.ipv4.addresses = [ (staticAddress postgresIps.database) ];

          networking.firewall.extraInputRules = ''
            ip saddr ${postgresIps.synapse} tcp dport 5432 accept
          '';

          services.postgresql = {
            enable = true;
            enableTCPIP = true;

            settings = {
              listen_addresses = lib.mkForce "*";
              password_encryption = "scram-sha-256";
            };

            authentication = ''
              local all all peer

              host testdb testuser ${postgresIps.synapse}/32 scram-sha-256
            '';

            initialScript = pkgs.writeText "postgresql-reachability-init.sql" ''
              CREATE USER testuser WITH PASSWORD 'testpass';
              CREATE DATABASE testdb OWNER testuser;
            '';
          };
        };

        synapse = { pkgs, ... }: {
          environment.systemPackages = [ pkgs.postgresql ];
          networking.firewall.enable = true;
          networking.nftables.enable = true;
          networking.interfaces.eth1.ipv4.addresses = [ (staticAddress postgresIps.synapse) ];
        };

        unrelated = { pkgs, ... }: {
          environment.systemPackages = [ pkgs.postgresql ];
          networking.firewall.enable = true;
          networking.nftables.enable = true;
          networking.interfaces.eth1.ipv4.addresses = [ (staticAddress postgresIps.unrelated) ];
        };
      };

      testScript = ''
        start_all()

        database.wait_for_unit("nftables.service")
        database.wait_for_unit("postgresql.service")

        for machine in [synapse, unrelated]:
            machine.wait_for_unit("multi-user.target")

        with subtest("the authorized Synapse host reaches PostgreSQL"):
            synapse.succeed(
                "PGCONNECT_TIMEOUT=10 PGPASSWORD=testpass psql "
                f"-h ${postgresIps.database} -U testuser -d testdb -c 'SELECT 1' >&2"
            )

        with subtest("an unrelated LAN host cannot reach PostgreSQL"):
            unrelated.fail(
                "PGCONNECT_TIMEOUT=10 PGPASSWORD=testpass psql "
                f"-h ${postgresIps.database} -U testuser -d testdb -c 'SELECT 1' >&2"
            )

        with subtest("PostgreSQL authorizes only the Synapse address for TCP"):
            hba_path = database.succeed(
                "sudo -u postgres psql -Atc 'SHOW hba_file'"
            ).strip()
            hba = database.succeed(f"cat {hba_path}")
            if "${postgresIps.synapse}" not in hba:
                raise Exception("PostgreSQL does not authorize the Synapse address")
      '';
    };
  };
in
assert lib.hasAttr test tests;
tests.${test}
