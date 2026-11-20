# Shoko restore drill.
#
# Validates the local recovery path for Shoko: create a representative
# configuration/database backup, restore it into the service state directory,
# restart Shoko, and verify its local HTTP API.
#
# The drill deliberately excludes production Shoko data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "shoko-restore-drill";

  nodes.shoko = { lib, ... }: {
    services.shoko = {
      enable = true;
      openFirewall = false;
    };

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    shoko.start()
    shoko.wait_for_unit("multi-user.target", timeout=120)
    shoko.wait_for_unit("shoko.service")
    shoko.wait_for_open_port(8111)

    backup_root = "/tmp/shoko-restore-drill"
    shoko_backup = f"{backup_root}/shoko"

    shoko.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Shoko local API is available before backup"):
        shoko.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8111/api/v3/system/status"
        )

    with subtest("representative Shoko state is backed up"):
        shoko.succeed(
          "install -d -m 0750 -o root -g root " + shlex.quote(shoko_backup)
        )

        database_probe = f"{shoko_backup}/ShokoServer.db"
        settings_probe = f"{shoko_backup}/ShokoServer.json"

        shoko.succeed(
          "install -m 0640 /dev/null " + shlex.quote(database_probe)
        )
        shoko.succeed(
          "truncate -s 1 " + shlex.quote(database_probe)
        )

        shoko.succeed(
          "install -m 0640 /dev/null " + shlex.quote(settings_probe)
        )
        shoko.succeed(
          "truncate -s 1 " + shlex.quote(settings_probe)
        )

        shoko.succeed(
          "cp -a /var/lib/shoko/. " + shlex.quote(shoko_backup) + "/"
        )

    with subtest("Shoko state restores into the service state directory"):
        shoko.succeed("systemctl stop shoko")
        shoko.succeed(
          "find /var/lib/shoko -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
        )
        shoko.succeed(
          "cp -a " + shlex.quote(shoko_backup) + "/. /var/lib/shoko/"
        )

        shoko.succeed("test -s /var/lib/shoko/ShokoServer.db")
        shoko.succeed("test -s /var/lib/shoko/ShokoServer.json")

    with subtest("Shoko starts against restored state"):
        shoko.succeed("systemctl start shoko")
        shoko.wait_for_unit("shoko.service")
        shoko.wait_for_open_port(8111)

        shoko.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8111/api/v3/system/status"
        )

    with subtest("temporary recovery artifacts are removed"):
        shoko.succeed("rm -rf -- /tmp/shoko-restore-drill")
  '';
}
