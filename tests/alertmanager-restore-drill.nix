# Alertmanager restore drill.
#
# Validates the local recovery path for Alertmanager: create a representative
# configuration/state backup, restore it into an isolated environment, start
# Alertmanager, and verify its local HTTP API.
#
# The drill deliberately excludes production Alertmanager data, secrets,
# Restic repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "alertmanager-restore-drill";

  nodes.alertmanager = { lib, ... }: {
    users.users.alertmanager = {
      isSystemUser = true;
      group = "alertmanager";
    };

    users.groups.alertmanager = { };

    services.prometheus.alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9093;
      openFirewall = false;

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
    restored_state = "/var/lib/alertmanager-restored"

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
          "install -d -m 0750 " + shlex.quote(alertmanager_backup)
        )

        alertmanager.succeed(
          "install -m 0640 /etc/alertmanager/alertmanager.yml "
          + shlex.quote(f"{alertmanager_backup}/alertmanager.yml")
        )

        alertmanager.succeed(
          "install -m 0640 /dev/null "
          + shlex.quote(f"{alertmanager_backup}/restore-manifest")
        )

        alertmanager.succeed(
          "cp -a /var/lib/alertmanager/. " + shlex.quote(alertmanager_backup) + "/state/"
        )

    with subtest("Alertmanager state restores into an isolated directory"):
        alertmanager.succeed(
          "install -d -m 0750 " + shlex.quote(restored_state)
        )

        alertmanager.succeed(
          "cp -a " + shlex.quote(alertmanager_backup) + "/state/. "
          + shlex.quote(restored_state) + "/"
        )

        alertmanager.succeed(
          "test -s " + shlex.quote(f"{restored_state}/restore-manifest")
        )
        alertmanager.succeed(
          "test -s /etc/alertmanager/alertmanager.yml"
        )

    with subtest("Alertmanager starts against restored state"):
        alertmanager.succeed("systemctl restart alertmanager.service")
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
