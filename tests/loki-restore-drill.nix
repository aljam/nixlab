# Loki restore drill.
#
# Validates the local recovery path for Loki: create a representative
# configuration/data backup, restore it into the service state directory,
# restart Loki, and verify its local HTTP API.
#
# The drill deliberately excludes production Loki data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "loki-restore-drill";

  nodes.loki = { lib, ... }: {
    services.loki = {
      enable = true;
      dataDir = "/var/lib/loki-restore";
      configuration = {
        auth_enabled = false;

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

        schema_config = {
          configs = [
            {
              from = "2026-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
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
    };

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

    loki.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    resolve_config = (
      "exec_line=\"$(systemctl show loki --property=ExecStart --value)\"; "
      "config=\"$(printf '%s\\n' \"$exec_line\" | sed -n "
      "-e 's/.*-config.file=\\([^[:space:]]*\\).*/\\1/p' "
      "-e 's/.*-config.file[[:space:]]\\+\\([^[:space:]]*\\).*/\\1/p')\"; "
      "if [ -z \"$config\" ]; then "
      "config=\"$(systemctl cat loki | sed -n "
      "-e 's/^ExecStart=.*-config.file=\\([^[:space:]]*\\).*/\\1/p' "
      "-e 's/^ExecStart=.*-config.file[[:space:]]\\+\\([^[:space:]]*\\).*/\\1/p')\"; "
      "fi; "
      "echo \"Loki ExecStart: $exec_line\" >&2; "
      "echo \"Resolved Loki config: $config\" >&2; "
      "test -n \"$config\"; test -s \"$config\""
    )

    with subtest("Loki local API is available before backup"):
        loki.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3100/ready"
        )

    with subtest("representative Loki state is backed up"):
        loki.succeed(
          "install -d -m 0750 -o root -g root " + shlex.quote(loki_backup)
        )

        loki.succeed(
          resolve_config + "; cp -a \"$config\" "
          + shlex.quote(f"{loki_backup}/config.yaml")
        )

        loki.succeed(
          "install -m 0640 /dev/null "
          + shlex.quote(f"{loki_backup}/restore-manifest")
        )
        loki.succeed(
          "truncate -s 1 "
          + shlex.quote(f"{loki_backup}/restore-manifest")
        )

        loki.succeed(
          "cp -aL /var/lib/loki-restore/. "
          + shlex.quote(f"{loki_backup}/data/")
        )

    with subtest("Loki state restores into the service state directory"):
        loki.succeed("systemctl stop loki")
        loki.succeed(
          "find -L /var/lib/loki-restore -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
        )
        loki.succeed(
          "cp -a " + shlex.quote(f"{loki_backup}/data")
          + "/. /var/lib/loki-restore/"
        )

        loki.succeed(
          "test -s " + shlex.quote(f"{loki_backup}/restore-manifest")
        )

    with subtest("Loki starts against restored state"):
        loki.succeed("systemctl start loki")
        loki.wait_for_unit("loki.service")
        loki.wait_for_open_port(3100)

        loki.succeed(
          resolve_config + "; "
          "sha256sum \"$config\" "
          + shlex.quote(f"{loki_backup}/config.yaml") +
          " | awk 'NR==1 {a=$1} NR==2 {b=$1} END {exit a==b ? 0 : 1}'"
        )

        loki.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3100/ready"
        )

    with subtest("temporary recovery artifacts are removed"):
        loki.succeed("rm -rf -- /tmp/loki-restore-drill")
  '';
}
