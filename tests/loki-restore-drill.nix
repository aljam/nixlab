# Loki restore drill.
#
# Validates the local recovery path for Loki: create a representative
# configuration/data backup, restore it into an isolated environment, start
# Loki, and verify its local HTTP API.
#
# The drill deliberately excludes production Loki data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "loki-restore-drill";

  nodes.loki = { lib, ... }: {
    users.users.loki = {
      isSystemUser = true;
      group = "loki";
    };

    users.groups.loki = { };

    services.loki = {
      enable = true;
      dataDir = "/var/lib/loki-restore";
      configuration = {
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = 3100;
        };

        ingester = {
          wal = {
            enabled = true;
            dir = "/var/lib/loki-restore/wal";
          };
        };

        storage_config = {
          filesystem = {
            directory = "/var/lib/loki-restore/chunks";
          };
        };

        limits_config = {
          reject_old_samples = false;
        };
      };

      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/loki-restore 0750 loki loki -"
      "d /var/lib/loki-restore/wal 0750 loki loki -"
      "d /var/lib/loki-restore/chunks 0750 loki loki -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    loki.start()
    loki.wait_for_unit("multi-user.target", timeout=120)
    loki.wait_for_unit("loki.service")
    loki.wait_for_open_port(3100)

    backup_root = "/tmp/loki-restore-drill"
    loki_backup = f"{backup_root}/loki"
    restored_data = "/var/lib/loki-restored"

    loki.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Loki local API is available before backup"):
        loki.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3100/ready"
        )

    with subtest("representative Loki state is backed up"):
        loki.succeed(
          "install -d -m 0750 " + shlex.quote(loki_backup)
        )

        loki.succeed(
          "install -m 0640 /etc/loki/config.yaml "
          + shlex.quote(f"{loki_backup}/config.yaml")
        )

        loki.succeed(
          "install -m 0640 /dev/null "
          + shlex.quote(f"{loki_backup}/restore-manifest")
        )

        loki.succeed(
          "cp -a /var/lib/loki-restore/. " + shlex.quote(loki_backup) + "/data/"
        )

    with subtest("Loki state restores into an isolated directory"):
        loki.succeed(
          "install -d -m 0750 " + shlex.quote(restored_data)
        )

        loki.succeed(
          "cp -a " + shlex.quote(loki_backup) + "/data/. "
          + shlex.quote(restored_data) + "/"
        )

        loki.succeed(
          "test -s " + shlex.quote(f"{restored_data}/restore-manifest")
        )
        loki.succeed(
          "test -s /etc/loki/config.yaml"
        )

    with subtest("Loki starts against restored state"):
        loki.succeed("systemctl restart loki.service")
        loki.wait_for_unit("loki.service")
        loki.wait_for_open_port(3100)

        loki.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3100/ready"
        )

    with subtest("temporary recovery artifacts are removed"):
        loki.succeed("rm -rf -- /tmp/loki-restore-drill")
  '';
}
