# Seerr restore drill.
#
# Validates the local recovery path for Seerr (formerly Jellyseerr): create a
# representative configuration/database backup, restore it into the service's
# state directory, restart Seerr, and verify its local HTTP API.
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

    jellyseerr.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Seerr local API is available before backup"):
        jellyseerr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:5055/api/v1/status"
        )

    with subtest("representative Seerr state is backed up"):
        jellyseerr.succeed(
          "install -d -m 0750 -o root -g root " + shlex.quote(seerr_backup)
        )

        database_probe = f"{seerr_backup}/db.db"
        settings_probe = f"{seerr_backup}/settings.json"

        jellyseerr.succeed(
          "install -m 0640 /dev/null " + shlex.quote(database_probe)
        )
        jellyseerr.succeed(
          "truncate -s 1 " + shlex.quote(database_probe)
        )

        jellyseerr.succeed(
          "install -m 0640 /dev/null " + shlex.quote(settings_probe)
        )
        jellyseerr.succeed(
          "truncate -s 1 " + shlex.quote(settings_probe)
        )

        # Seerr uses a systemd dynamic user, so perform the state backup as
        # root rather than relying on a stable service-user identity.
        jellyseerr.succeed(
          "cp -a /var/lib/seerr/. " + shlex.quote(seerr_backup) + "/"
        )

    with subtest("Seerr state restores into the service state directory"):
        jellyseerr.succeed("systemctl stop seerr")
        jellyseerr.succeed(
          "find /var/lib/seerr -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
        )
        jellyseerr.succeed(
          "cp -a " + shlex.quote(seerr_backup) + "/. /var/lib/seerr/"
        )

        jellyseerr.succeed(
          "test -s /var/lib/seerr/db.db"
        )
        jellyseerr.succeed(
          "test -s /var/lib/seerr/settings.json"
        )

    with subtest("Seerr starts against restored state"):
        jellyseerr.succeed("systemctl start seerr")
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
