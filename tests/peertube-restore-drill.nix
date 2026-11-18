# PeerTube restore drill.
#
# Validates the local recovery path: create a representative PeerTube
# PostgreSQL database backup and video-storage state, restore both into an
# isolated environment, start PeerTube, and verify its local HTTP API.
#
# The drill deliberately excludes production PeerTube databases, media,
# secrets, Restic repositories, federation, public HTTPS access, and
# external object storage.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "peertube-restore-drill";

  nodes.peertube = { lib, ... }: {
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "peertube_restore" ];
      ensureUsers = [
        {
          name = "peertube_restore";
          ensureDBOwnership = true;
        }
      ];
      settings = {
        listen_addresses = lib.mkForce "127.0.0.1";
        password_encryption = "scram-sha-256";
      };
      authentication = lib.mkForce ''
        local all all peer
        host peertube_restore peertube_restore 127.0.0.1/32 scram-sha-256
        host all all 127.0.0.1/32 reject
      '';
    };

    services.redis.servers.peertube = {
      enable = true;
      port = 6379;
      bind = "127.0.0.1";
    };

    services.peertube = {
      enable = true;

      localDomain = "peertube-restore-drill.invalid";

      listenHttp = 9000;
      listenWeb = 9000;
      enableWebHttps = false;

      secrets.secretsFile = "/etc/peertube-restore-secrets";

      redis = {
        enableUnixSocket = false;
        host = "127.0.0.1";
        port = 6379;
      };

      database = {
        host = "127.0.0.1";
        port = 5432;
        name = "peertube_restore";
        user = "peertube_restore";
        passwordFile = "/etc/peertube-restore-db-password";
      };

      settings = {
        listen = {
          hostname = "127.0.0.1";
          port = 9000;
        };

        database.ssl = false;

        instance.name = "PeerTube restore drill";
        instance.short_description = "Isolated restore drill";
        storage.videos = "/var/lib/peertube-restore/storage/videos";
        storage.streaming_playlists = "/var/lib/peertube-restore/storage/streaming-playlists";
        signup.enabled = false;
      };
    };

    systemd.services.peertube.wantedBy = lib.mkForce [ ];

    environment.etc."peertube-restore-db-password" = {
      mode = "0400";
      user = "peertube";
      text = "vm-only-peertube-restore";
    };

    environment.etc."peertube-restore-secrets" = {
      mode = "0400";
      user = "peertube";
      text = "vm-only-peertube-restore-secret\n";
    };

    users.users.peertube.extraGroups = [ "peertube-restore" ];
    users.groups.peertube-restore = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/peertube-restore 0750 peertube peertube-restore -"
      "d /var/lib/peertube-restore/storage 0750 peertube peertube-restore -"
      "d /var/lib/peertube-restore/storage/videos 0750 peertube peertube-restore -"
      "d /var/lib/peertube-restore/storage/streaming-playlists 0750 peertube peertube-restore -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
      postgresql
    ];
  };

  testScript = ''
    import shlex

    peertube.start()
    peertube.wait_for_unit("postgresql.service")
    peertube.wait_for_unit("postgresql-setup.service")
    peertube.wait_for_unit("redis-peertube.service")

    peertube.succeed(
      "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "
      + shlex.quote("ALTER ROLE peertube_restore PASSWORD 'vm-only-peertube-restore'")
    )

    backup_root = "/tmp/peertube-restore-drill"
    database_backup = f"{backup_root}/peertube_restore.dump"
    videos_backup = f"{backup_root}/videos"

    peertube.succeed(
      "install -d -m 0700 -o peertube -g peertube-restore "
      + shlex.quote(backup_root)
    )

    with subtest("PeerTube local API is available before backup"):
        peertube.succeed("systemctl start peertube.service")
        peertube.succeed("sleep 30")
        peertube.succeed(
          "journalctl -u peertube.service --no-pager | tail -n 300"
        )
        peertube.wait_for_unit("peertube.service")
        peertube.wait_for_open_port(9000)

        output = peertube.succeed(
          "curl --fail --silent --show-error "
          "http://127.0.0.1:9000/api/v1/search/videos/ | jq -e 'has(\"total\")'"
        )

    with subtest("representative PeerTube state is backed up"):
        peertube.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d peertube_restore -c "
          + shlex.quote(
            "CREATE TABLE restore_probe (id integer PRIMARY KEY, label text); "
            "INSERT INTO restore_probe VALUES (1, 'restore-drill');"
          )
        )
        peertube.succeed(
          "sudo -u postgres pg_dump --dbname=peertube_restore "
          "--format=custom --file=" + shlex.quote(database_backup)
        )
        peertube.succeed("test -s " + shlex.quote(database_backup))

        peertube.succeed(
          "sudo -u peertube install -d -m 0750 "
          + shlex.quote(videos_backup)
        )
        peertube.succeed(
          "sudo -u peertube install -m 0640 /dev/null "
          + shlex.quote(f"{videos_backup}/restore-probe")
        )

    with subtest("PeerTube database restores into an isolated database"):
        restored_database = "peertube_restored"

        peertube.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 -c "
          + shlex.quote(
            f"CREATE DATABASE {restored_database} OWNER peertube_restore"
          )
        )
        peertube.succeed(
          "sudo -u postgres pg_restore --dbname=" + shlex.quote(restored_database) + " "
          "--exit-on-error " + shlex.quote(database_backup)
        )

        output = peertube.succeed(
          "sudo -u postgres psql -X -v ON_ERROR_STOP=1 --tuples-only --no-align "
          "--dbname=" + shlex.quote(restored_database) + " --command="
          + shlex.quote("SELECT label FROM restore_probe WHERE id = 1")
        )
        assert output.strip() == "restore-drill", output

    with subtest("PeerTube video storage restores with intended ownership"):
        peertube.succeed(
          "sudo -u peertube install -d -m 0750 "
          "/var/lib/peertube-restore/restored-storage/videos"
        )
        peertube.succeed(
          "sudo -u peertube cp -a "
          + shlex.quote(videos_backup)
          + "/. /var/lib/peertube-restore/restored-storage/videos/"
        )
        peertube.succeed(
          "stat -c '%U %G' "
          "/var/lib/peertube-restore/restored-storage/videos/restore-probe "
          "| grep -q 'peertube peertube-restore'"
        )

    with subtest("PeerTube starts against restored database and storage"):
        peertube.succeed("systemctl restart peertube.service")
        peertube.wait_for_unit("peertube.service")
        peertube.wait_for_open_port(9000)

        output = peertube.succeed(
          "curl --fail --silent --show-error "
          "http://127.0.0.1:9000/api/v1/search/videos/ | jq -e 'has(\"total\")'"
        )

    with subtest("temporary recovery artifacts are removed"):
        peertube.succeed("rm -rf -- /tmp/peertube-restore-drill")
  '';
}
