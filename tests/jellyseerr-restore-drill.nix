# Seerr restore drill.
#
# Validates the local recovery path for Seerr (formerly Jellyseerr): create a
# representative configuration/database backup, restore it into an isolated
# environment, start Seerr, and verify its local HTTP API.
#
# The drill deliberately excludes production Seerr data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "jellyseerr-restore-drill";

  nodes.jellyseerr = { lib, ... }: {
    services.seerr = {
      enable = true;
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/seerr-restored 0750 seerr seerr -"
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
    jellyseerr.wait_for_unit("seerr.service")
    jellyseerr.wait_for_open_port(5055)

    backup_root = "/tmp/jellyseerr-restore-drill"
    seerr_backup = f"{backup_root}/seerr"
    restored_state = "/var/lib/seerr-restored"

    jellyseerr.succeed(
      "install -d -m 0775 -o root -g seerr " + shlex.quote(backup_root)
    )

    with subtest("Seerr local API is available before backup"):
        jellyseerr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:5055/api/v1/status"
        )

    with subtest("representative Seerr state is backed up"):
        jellyseerr.succeed(
          "sudo -u seerr install -d -m 0750 " + shlex.quote(seerr_backup)
        )

        database_probe = f"{seerr_backup}/db.db"
        settings_probe = f"{seerr_backup}/settings.json"

        jellyseerr.succeed(
          "sudo -u seerr install -m 0640 /dev/null "
          + shlex.quote(database_probe)
        )
        jellyseerr.succeed(
          "sudo -u seerr truncate -s 1 " + shlex.quote(database_probe)
        )

        jellyseerr.succeed(
          "sudo -u seerr install -m 0640 /dev/null "
          + shlex.quote(settings_probe)
        )
        jellyseerr.succeed(
          "sudo -u seerr truncate -s 1 " + shlex.quote(settings_probe)
        )

        jellyseerr.succeed(
          "sudo -u seerr cp -a /var/lib/seerr/. "
          + shlex.quote(seerr_backup) + "/"
        )

    with subtest("Seerr state restores into an isolated directory"):
        jellyseerr.succeed(
          "sudo -u seerr cp -a " + shlex.quote(seerr_backup) + "/. "
          + shlex.quote(restored_state) + "/"
        )

        jellyseerr.succeed(
          "sudo -u seerr test -s " + shlex.quote(f"{restored_state}/db.db")
        )
        jellyseerr.succeed(
          "sudo -u seerr test -s "
          + shlex.quote(f"{restored_state}/settings.json")
        )

    with subtest("Seerr starts against restored state"):
        # Restarting a system unit requires root; the Seerr service user does
        # not have permission to manage systemd units.
        jellyseerr.succeed("systemctl restart seerr.service")
        jellyseerr.wait_for_unit("seerr.service")
        jellyseerr.wait_for_open_port(5055)

        jellyseerr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:5055/api/v1/status"
        )

    with subtest("temporary recovery artifacts are removed"):
        jellyseerr.succeed("rm -rf -- /tmp/jellyseerr-restore-drill")
  '';
}
