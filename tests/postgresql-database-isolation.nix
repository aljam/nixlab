{ pkgs }:

pkgs.testers.nixosTest {
  name = "postgresql-database-isolation";

  nodes.database = { lib, ... }: {
    services.postgresql = {
      enable = true;
      enableTCPIP = true;
      ensureDatabases = [
        "service_a"
        "service_b"
      ];
      ensureUsers = [
        {
          name = "service_a";
          ensureDBOwnership = true;
        }
        {
          name = "service_b";
          ensureDBOwnership = true;
        }
      ];
      settings = {
        listen_addresses = lib.mkForce "127.0.0.1";
        password_encryption = "scram-sha-256";
      };
      authentication = lib.mkForce ''
        local all all peer
        host service_a service_a 127.0.0.1/32 scram-sha-256
        host service_b service_b 127.0.0.1/32 scram-sha-256
        host all all 127.0.0.1/32 reject
      '';
    };
  };

  testScript = ''
    import shlex

    database.start()
    database.wait_for_unit("postgresql.service")
    database.wait_for_unit("postgresql-setup.service")

    # Disposable VM-only credentials, never production secrets.
    for role in ["service_a", "service_b"]:
        sql = f"ALTER ROLE {role} PASSWORD 'vm-only-{role}'"
        database.succeed("sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c " + shlex.quote(sql))

    def query(role, db, sql):
        return (
            f"PGCONNECT_TIMEOUT=5 PGPASSWORD=vm-only-{role} "
            f"psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U {role} -d {db} -c "
            + shlex.quote(sql)
            + " 2>&1"
        )

    for role, other in [("service_a", "service_b"), ("service_b", "service_a")]:
        with subtest(f"{role} can use its own database"):
            database.succeed(query(role, role, "CREATE TABLE isolation_probe (id integer); INSERT INTO isolation_probe VALUES (1); SELECT * FROM isolation_probe"))

        with subtest(f"{role} cannot connect to {other}"):
            status, output = database.execute(query(role, other, "SELECT 1"))
            assert status != 0 and "pg_hba.conf rejects connection" in output, output

        for sql, expected in [
            (f"CREATE DATABASE forbidden_{role}", "permission denied to create database"),
            (f"CREATE ROLE forbidden_{role}", "permission denied to create role"),
        ]:
            with subtest(f"{role} is denied: {sql}"):
                status, output = database.execute(query(role, role, sql))
                assert status != 0 and expected in output, output
  '';
}
