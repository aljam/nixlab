{ pkgs }:

pkgs.testers.nixosTest {
  name = "postgresql-restore-drill";

  nodes.database = { lib, ... }: {
    services.postgresql = {
      enable = true;
      enableTCPIP = false;
      ensureDatabases = [ "restore_probe" ];
      ensureUsers = [
        {
          name = "restore_probe";
          ensureDBOwnership = true;
        }
      ];
      settings = {
        listen_addresses = lib.mkForce "127.0.0.1";
        password_encryption = "scram-sha-256";
      };
      authentication = lib.mkForce ''
        local all all peer
        host restore_probe restore_probe 127.0.0.1/32 scram-sha-256
        host all all 127.0.0.1/32 reject
      '';
    };

    environment.systemPackages = with pkgs; [
      postgresql
    ];
  };

  testScript = ''
    import shlex

    database.start()
    database.wait_for_unit("postgresql.service")
    database.wait_for_unit("postgresql-setup.service")

    database.succeed(
      "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "
      + shlex.quote("ALTER ROLE restore_probe PASSWORD 'vm-only-restore-probe'")
    )

    dump_path = "/tmp/postgresql-restore-drill/restore_probe.dump"
    restore_data = "/tmp/postgresql-restore-drill/data"

    database.succeed(
      "install -d -m 0700 -o postgres -g postgres /tmp/postgresql-restore-drill "
      + shlex.quote(restore_data)
    )

    with subtest("representative custom-format dump is created"):
        database.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d restore_probe -c "
          + shlex.quote(
            "CREATE TABLE restore_probe (id integer PRIMARY KEY, label text); "
            "INSERT INTO restore_probe VALUES (1, 'restore-drill');"
          )
        )
        database.succeed(
          "sudo -u postgres pg_dump --dbname=restore_probe --format=custom --file="
          + shlex.quote(dump_path)
        )
        database.succeed("test -s " + shlex.quote(dump_path))

    with subtest("custom-format dump restores into isolated cluster"):
        database.succeed(
          "sudo -u postgres initdb --pgdata="
          + shlex.quote(restore_data)
          + " --auth-local=peer --auth-host=scram-sha-256"
        )
        database.succeed(
          "sudo -u postgres pg_ctl "
          "--pgdata="
          + shlex.quote(restore_data)
          + " --log=/tmp/postgresql-restore-drill/postgresql.log "
          "--options='-k /tmp -p 5433' start"
        )
        database.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 "
          "--host=/tmp --port=5433 --dbname=postgres --command="
          + shlex.quote("CREATE ROLE restore_probe LOGIN")
        )
        database.succeed(
          "sudo -u postgres pg_restore --dbname=postgres --host=/tmp --port=5433 "
          "--create --exit-on-error "
          + shlex.quote(dump_path)
        )

    with subtest("restored database accepts a functional query"):
        output = database.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 "
          "--host=/tmp --port=5433 --dbname=restore_probe --tuples-only --no-align --command="
          + shlex.quote("SELECT label FROM restore_probe WHERE id = 1")
        )
        assert output.strip() == "restore-drill", output

    with subtest("isolated restore cluster is stopped and removed"):
        database.succeed(
          "sudo -u postgres pg_ctl --pgdata="
          + shlex.quote(restore_data)
          + " stop --mode=fast"
        )
        database.succeed("rm -rf -- /tmp/postgresql-restore-drill")
  '';
}
