# Shoko restore drill.
#
# Validates the local recovery path for Shoko: create a representative
# configuration/database backup, restore it into an isolated environment,
# start Shoko, and verify its local HTTP API.
#
# The drill deliberately excludes production Shoko data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "shoko-restore-drill";

  nodes.shoko = { lib, ... }: {
    users.users.shoko = {
      isSystemUser = true;
      group = "shoko";
    };

    users.groups.shoko = { };

    services.shoko = {
      enable = true;
      dataDir = "/var/lib/shoko-restore";
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/shoko-restore 0750 shoko shoko -"
    ];

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
    restored_state = "/var/lib/shoko-restored"

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
          "sudo -u shoko install -d -m 0750 " + shlex.quote(shoko_backup)
        )

        shoko.succeed(
          "sudo -u shoko install -m 0640 /dev/null "
          + shlex.quote(f"{shoko_backup}/ShokoServer.db")
        )
        shoko.succeed(
          "sudo -u shoko install -m 0640 /dev/null "
          + shlex.quote(f"{shoko_backup}/ShokoServer.json")
        )

        shoko.succeed(
          "sudo -u shoko cp -a /var/lib/shoko-restore/. "
          + shlex.quote(shoko_backup) + "/"
        )

    with subtest("Shoko state restores into an isolated directory"):
        shoko.succeed(
          "sudo -u shoko install -d -m 0750 " + shlex.quote(restored_state)
        )

        shoko.succeed(
          "sudo -u shoko cp -a " + shlex.quote(shoko_backup) + "/. "
          + shlex.quote(restored_state) + "/"
        )

        shoko.succeed(
          "sudo -u shoko test -s " + shlex.quote(f"{restored_state}/ShokoServer.db")
        )
        shoko.succeed(
          "sudo -u shoko test -s " + shlex.quote(f"{restored_state}/ShokoServer.json")
        )

    with subtest("Shoko starts against restored state"):
        shoko.succeed(
          "sudo -u shoko systemctl restart shoko.service"
        )
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
