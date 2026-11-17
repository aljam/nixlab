# Jellyseerr restore drill.
#
# Validates the local recovery path for Jellyseerr: create a representative
# configuration/database backup, restore it into an isolated environment,
# start Jellyseerr, and verify its local HTTP API.
#
# The drill deliberately excludes production Jellyseerr data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "jellyseerr-restore-drill";

  nodes.jellyseerr = { lib, ... }: {
    users.users.jellyseerr = {
      isSystemUser = true;
      group = "jellyseerr";
    };

    users.groups.jellyseerr = { };

    services.jellyseerr = {
      enable = true;
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/jellyseerr 0750 jellyseerr jellyseerr -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    jellyseerr.start()
    jellyseerr.wait_for_unit("multi-user.target", timeout=120)
    jellyseerr.wait_for_unit("jellyseerr.service")
    jellyseerr.wait_for_open_port(5055)

    backup_root = "/tmp/jellyseerr-restore-drill"
    jellyseerr_backup = f"{backup_root}/jellyseerr"
    restored_state = "/var/lib/jellyseerr-restored"

    jellyseerr.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Jellyseerr local API is available before backup"):
        jellyseerr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:5055/api/v1/status"
        )

    with subtest("representative Jellyseerr state is backed up"):
        jellyseerr.succeed(
          "sudo -u jellyseerr install -d -m 0750 " + shlex.quote(jellyseerr_backup)
        )

        jellyseerr.succeed(
          "sudo -u jellyseerr install -m 0640 /dev/null "
          + shlex.quote(f"{jellyseerr_backup}/db.db")
        )
        jellyseerr.succeed(
          "sudo -u jellyseerr install -m 0640 /dev/null "
          + shlex.quote(f"{jellyseerr_backup}/settings.json")
        )

        jellyseerr.succeed(
          "sudo -u jellyseerr cp -a /var/lib/jellyseerr/. "
          + shlex.quote(jellyseerr_backup) + "/"
        )

    with subtest("Jellyseerr state restores into an isolated directory"):
        jellyseerr.succeed(
          "sudo -u jellyseerr install -d -m 0750 " + shlex.quote(restored_state)
        )

        jellyseerr.succeed(
          "sudo -u jellyseerr cp -a " + shlex.quote(jellyseerr_backup) + "/. "
          + shlex.quote(restored_state) + "/"
        )

        jellyseerr.succeed(
          "sudo -u jellyseerr test -s " + shlex.quote(f"{restored_state}/db.db")
        )
        jellyseerr.succeed(
          "sudo -u jellyseerr test -s " + shlex.quote(f"{restored_state}/settings.json")
        )

    with subtest("Jellyseerr starts against restored state"):
        jellyseerr.succeed(
          "sudo -u jellyseerr systemctl restart jellyseerr.service"
        )
        jellyseerr.wait_for_unit("jellyseerr.service")
        jellyseerr.wait_for_open_port(5055)

        jellyseerr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:5055/api/v1/status"
        )

    with subtest("temporary recovery artifacts are removed"):
        jellyseerr.succeed("rm -rf -- /tmp/jellyseerr-restore-drill")
  '';
}
