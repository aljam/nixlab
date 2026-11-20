{ pkgs }:

pkgs.testers.nixosTest {
  name = "grafana-restore-drill";

  nodes.grafana = { lib, ... }: {
    environment.etc."grafana-secret-key".text = "test-grafana-secret-key";

    services.grafana = {
      enable = true;
      dataDir = "/var/lib/grafana-restore";
      addr = "127.0.0.1";
      port = 3001;
      openFirewall = false;

      settings.security.secret_key = "$__file{/etc/grafana-secret-key}";
    };

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
          "install -d -m 0750 -o root -g root " + shlex.quote(grafana_backup)
        )

        database_probe = f"{grafana_backup}/grafana.db"
        settings_probe = f"{grafana_backup}/grafana.ini"

        grafana.succeed(
          "install -m 0640 /dev/null " + shlex.quote(database_probe)
        )
        grafana.succeed(
          "truncate -s 1 " + shlex.quote(database_probe)
        )

        grafana.succeed(
          "install -m 0640 /dev/null " + shlex.quote(settings_probe)
        )
        grafana.succeed(
          "truncate -s 1 " + shlex.quote(settings_probe)
        )

        grafana.succeed(
          "cp -a /var/lib/grafana-restore/. " + shlex.quote(grafana_backup) + "/"
        )

    with subtest("Grafana state restores into the service state directory"):
        grafana.succeed("systemctl stop grafana")
        grafana.succeed(
          "find /var/lib/grafana-restore -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
        )
        grafana.succeed(
          "cp -a " + shlex.quote(grafana_backup) + "/. /var/lib/grafana-restore/"
        )

        grafana.succeed("test -s /var/lib/grafana-restore/grafana.db")
        grafana.succeed("test -s /var/lib/grafana-restore/grafana.ini")

    with subtest("Grafana starts against restored state"):
        grafana.succeed("systemctl start grafana")
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
