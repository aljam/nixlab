# Matrix Synapse restore drill.
#
# Validates the local recovery path: create a representative Synapse
# PostgreSQL backup, restore it into an isolated database, restore a
# temporary media store, start Synapse, and verify its local client API.
#
# The drill deliberately excludes federation, LiveKit RTC, public
# registration, production secrets, and production media or databases.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "matrix-restore-drill";

  nodes.matrix = { lib, ... }: {
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "matrix_synapse_restore" ];
      ensureUsers = [
        {
          name = "matrix_synapse_restore";
          ensureDBOwnership = true;
        }
      ];
      settings = {
        listen_addresses = lib.mkForce "127.0.0.1";
        password_encryption = "scram-sha-256";
      };
      authentication = lib.mkForce ''
        local all all peer
        host matrix_synapse_restore matrix_synapse_restore 127.0.0.1/32 scram-sha-256
        host all all 127.0.0.1/32 reject
      '';
    };

    services.matrix-synapse = {
      enable = true;

      settings = {
        server_name = "restore-drill.invalid";
        public_baseurl = "http://127.0.0.1:8008";

        media_store_path = "/var/lib/matrix-synapse-restore/media_store";

        database = {
          name = "psycopg2";
          args = {
            database = "matrix_synapse_restore";
            user = "matrix_synapse_restore";
            host = "127.0.0.1";
            password = "vm-only-matrix-restore";
            sslmode = "disable";
            cp_min = 1;
            cp_max = 2;
          };
        };

        listeners = [
          {
            port = 8008;
            bind_addresses = [ "127.0.0.1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = [ "client" ];
                compress = false;
              }
            ];
          }
        ];

        enable_registration = false;
      };
    };

    users.users.matrix-synapse.extraGroups = [ "matrix-synapse-restore" ];
    users.groups.matrix-synapse-restore = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/matrix-synapse-restore 0750 matrix-synapse matrix-synapse-restore -"
      "d /var/lib/matrix-synapse-restore/media_store 0750 matrix-synapse matrix-synapse-restore -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
      postgresql
    ];
  };

  testScript = ''
    import shlex

    matrix.start()
    matrix.wait_for_unit("postgresql.service")
    matrix.wait_for_unit("postgresql-setup.service")

    matrix.succeed(
      "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "
      + shlex.quote("ALTER ROLE matrix_synapse_restore PASSWORD 'vm-only-matrix-restore'")
    )

    # Synapse requires a C-collated database. Recreate the VM-only
    # restore database before Synapse starts its service restart loop.
    matrix.succeed("systemctl stop matrix-synapse.service || true")
    matrix.succeed(
      "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "
      + shlex.quote("DROP DATABASE IF EXISTS matrix_synapse_restore")
    )
    matrix.succeed(
      "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "
      + shlex.quote(
        "CREATE DATABASE matrix_synapse_restore OWNER matrix_synapse_restore "
        "TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'"
      )
    )

    dump_path = "/tmp/matrix-restore-drill/matrix_synapse_restore.dump"
    restored_database = "matrix_synapse_restored"

    matrix.succeed(
      "install -d -m 0700 -o matrix-synapse -g matrix-synapse-restore "
      "/tmp/matrix-restore-drill"
    )

    with subtest("representative Synapse database backup is created"):
        matrix.succeed("systemctl start matrix-synapse.service")
        matrix.wait_for_unit("matrix-synapse.service")
        matrix.wait_for_open_port(8008)

        matrix.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8008/_matrix/client/versions"
          " | jq -e '.versions | length > 0'"
        )

        matrix.succeed(
          "sudo -u postgres pg_dump --dbname=matrix_synapse_restore "
          "--format=custom --file=" + shlex.quote(dump_path)
        )
        matrix.succeed("test -s " + shlex.quote(dump_path))

    with subtest("Synapse database restores into an isolated database"):
        matrix.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "
          + shlex.quote(f"CREATE DATABASE {restored_database} OWNER matrix_synapse_restore TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'")
        )
        matrix.succeed(
          "sudo -u postgres pg_restore --dbname=" + shlex.quote(restored_database) + " "
          "--exit-on-error " + shlex.quote(dump_path)
        )

        output = matrix.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 --tuples-only --no-align "
          "--dbname=" + shlex.quote(restored_database) + " --command="
          + shlex.quote("SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public'")
        )
        assert int(output.strip()) > 0, output

    with subtest("temporary media store is restored with intended ownership"):
        matrix.succeed(
          "sudo -u matrix-synapse install -d -m 0750 "
          "/var/lib/matrix-synapse-restore/media_store/restored"
        )
        matrix.succeed(
          "sudo -u matrix-synapse install -m 0640 /dev/null "
          "/var/lib/matrix-synapse-restore/media_store/restored/probe"
        )
        matrix.succeed(
          "stat -c '%U %G' /var/lib/matrix-synapse-restore/media_store/restored/probe "
          "| grep -q 'matrix-synapse matrix-synapse-restore'"
        )

    with subtest("Synapse starts against restored database and media store"):
        matrix.succeed(
          "sudo -u matrix-synapse systemctl restart matrix-synapse.service"
        )
        matrix.wait_for_unit("matrix-synapse.service")
        matrix.wait_for_open_port(8008)

        matrix.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8008/_matrix/client/versions"
          " | jq -e '.versions | length > 0'"
        )

    with subtest("temporary recovery artifacts are removed"):
        matrix.succeed("rm -rf -- /tmp/matrix-restore-drill")
  '';
}
