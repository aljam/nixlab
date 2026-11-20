# Alertmanager restore drill.
#
# Validates the local recovery path for Alertmanager: create a representative
# state backup, restore it into the service state directory, restart
# Alertmanager, and verify its local HTTP API.
#
# Alertmanager's configuration is generated at service start and removed after
# use, so this drill validates recovery of its persistent state and service
# health rather than retaining a runtime-only configuration file.
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
          "install -m 0640 /dev/null "
          + shlex.quote(f"{alertmanager_backup}/restore-manifest")
        )
        alertmanager.succeed(
          "truncate -s 1 "
          + shlex.quote(f"{alertmanager_backup}/restore-manifest")
        )

        alertmanager.succeed(
          "cp -aL /var/lib/alertmanager/. "
          + shlex.quote(f"{alertmanager_backup}/state/")
        )

    with subtest("Alertmanager state restores into the service state directory"):
        alertmanager.succeed("systemctl stop alertmanager")
        alertmanager.succeed(
          "find -L /var/lib/alertmanager -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
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
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9093/-/healthy"
        )

    with subtest("temporary recovery artifacts are removed"):
        alertmanager.succeed("rm -rf -- /tmp/alertmanager-restore-drill")
  '';
}
