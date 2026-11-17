# Grafana restore drill.
#
# Validates the local recovery path for Grafana: create a representative
# configuration/database backup, restore it into an isolated environment,
# start Grafana, and verify its local HTTP API.
#
# The drill deliberately excludes production Grafana data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "grafana-restore-drill";

  nodes.grafana = { lib, ... }: {
    users.users.grafana = {
      isSystemUser = true;
      group = "grafana";
    };

    users.groups.grafana = { };

    services.grafana = {
      enable = true;
      dataDir = "/var/lib/grafana-restore";
      addr = "127.0.0.1";
      port = 3001;
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/grafana-restore 0750 grafana grafana -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    grafana.start()
    grafana.wait_for_unit("multi-user.target", timeout=120)
    grafana.wait_for_unit("grafana.service")
    grafana.wait_for_open_port(3001)

    backup_root = "/tmp/grafana-restore-drill"
    grafana_backup = f"{backup_root}/grafana"
    restored_state = "/var/lib/grafana-restored"

    grafana.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Grafana local API is available before backup"):
        grafana.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3001/api/health"
        )

    with subtest("representative Grafana state is backed up"):
        grafana.succeed(
          "sudo -u grafana install -d -m 0750 " + shlex.quote(grafana_backup)
        )

        grafana.succeed(
          "sudo -u grafana install -m 0640 /dev/null "
          + shlex.quote(f"{grafana_backup}/grafana.db")
        )
        grafana.succeed(
          "sudo -u grafana install -m 0640 /dev/null "
          + shlex.quote(f"{grafana_backup}/grafana.ini")
        )

        grafana.succeed(
          "sudo -u grafana cp -a /var/lib/grafana-restore/. "
          + shlex.quote(grafana_backup) + "/"
        )

    with subtest("Grafana state restores into an isolated directory"):
        grafana.succeed(
          "sudo -u grafana install -d -m 0750 " + shlex.quote(restored_state)
        )

        grafana.succeed(
          "sudo -u grafana cp -a " + shlex.quote(grafana_backup) + "/. "
          + shlex.quote(restored_state) + "/"
        )

        grafana.succeed(
          "sudo -u grafana test -s " + shlex.quote(f"{restored_state}/grafana.db")
        )
        grafana.succeed(
          "sudo -u grafana test -s " + shlex.quote(f"{restored_state}/grafana.ini")
        )

    with subtest("Grafana starts against restored state"):
        grafana.succeed(
          "sudo -u grafana systemctl restart grafana.service"
        )
        grafana.wait_for_unit("grafana.service")
        grafana.wait_for_open_port(3001)

        grafana.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3001/api/health"
        )

    with subtest("temporary recovery artifacts are removed"):
        grafana.succeed("rm -rf -- /tmp/grafana-restore-drill")
  '';
}
