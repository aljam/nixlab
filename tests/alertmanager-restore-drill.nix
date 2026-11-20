# Alertmanager restore drill.
#
# Validates the local recovery path for Alertmanager: create a representative
# configuration/state backup, restore it into the service state directory,
# restart Alertmanager, and verify its local HTTP API.
#
# The drill deliberately excludes production Alertmanager data, secrets,
# Restic repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "alertmanager-restore-drill";

  nodes.alertmanager = { lib, ... }: {
    services.prometheus.alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9093;

      configuration = {
        global = {
          resolve_timeout = "5m";
        };

        route = {
          receiver = "restore-drill";
          group_by = [ "alertname" ];
        };

        receivers = [
          {
            name = "restore-drill";
          }
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    alertmanager.start()
    alertmanager.wait_for_unit("multi-user.target", timeout=120)
    alertmanager.wait_for_unit("alertmanager.service")
    alertmanager.wait_for_open_port(9093)

    backup_root = "/tmp/alertmanager-restore-drill"
    alertmanager_backup = f"{backup_root}/alertmanager"

    alertmanager.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    resolve_config = r'''
      exec_line="$(systemctl show alertmanager --property=ExecStart --value)"
      config="$(printf '%s\n' "$exec_line" | sed -n -e 's/.*--config.file=\([^[:space:]]*\).*/\1/p' -e 's/.*--config.file[[:space:]]\+\([^[:space:]]*\).*/\1/p')"

      if [ -z "$config" ]; then
        config="$(systemctl cat alertmanager | sed -n -e 's/^ExecStart=.*--config.file=\([^[:space:]]*\).*/\1/p' -e 's/^ExecStart=.*--config.file[[:space:]]\+\([^[:space:]]*\).*/\1/p')"
      fi

      echo "Alertmanager ExecStart: $exec_line" >&2
      echo "Resolved Alertmanager config: $config" >&2

      test -n "$config"
      test -s "$config"
    '''

    with subtest("Alertmanager local API is available before backup"):
        alertmanager.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9093/-/healthy"
        )

    with subtest("representative Alertmanager state is backed up"):
        alertmanager.succeed(
          "install -d -m 0750 -o root -g root " + shlex.quote(alertmanager_backup)
        )

        alertmanager.succeed(
          resolve_config + "; cp -a \"$config\" "
          + shlex.quote(f"{alertmanager_backup}/alertmanager.yml")
        )

        alertmanager.succeed(
          "install -m 0640 /dev/null "
          + shlex.quote(f"{alertmanager_backup}/restore-manifest")
        )
        alertmanager.succeed(
          "truncate -s 1 "
          + shlex.quote(f"{alertmanager_backup}/restore-manifest")
        )

        alertmanager.succeed(
          "cp -a /var/lib/alertmanager "
          + shlex.quote(f"{alertmanager_backup}/state")
        )

    with subtest("Alertmanager state restores into the service state directory"):
        alertmanager.succeed("systemctl stop alertmanager")
        alertmanager.succeed(
          "find /var/lib/alertmanager -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
        )
        alertmanager.succeed(
          "cp -a " + shlex.quote(f"{alertmanager_backup}/state")
          + "/. /var/lib/alertmanager/"
        )

        alertmanager.succeed(
          "test -s " + shlex.quote(f"{alertmanager_backup}/restore-manifest")
        )

    with subtest("Alertmanager starts against restored state"):
        alertmanager.succeed("systemctl start alertmanager")
        alertmanager.wait_for_unit("alertmanager.service")
        alertmanager.wait_for_open_port(9093)

        alertmanager.succeed(
          resolve_config + "; "
          "sha256sum \"$config\" "
          + shlex.quote(f"{alertmanager_backup}/alertmanager.yml") +
          " | awk 'NR==1 {a=$1} NR==2 {b=$1} END {exit a==b ? 0 : 1}'"
        )

        alertmanager.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9093/-/healthy"
        )

    with subtest("temporary recovery artifacts are removed"):
        alertmanager.succeed("rm -rf -- /tmp/alertmanager-restore-drill")
  '';
}
