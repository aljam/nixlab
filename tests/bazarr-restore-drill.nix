# Bazarr restore drill.
#
# Validates the local recovery path: create a representative Bazarr
# configuration/database backup, restore it into an isolated environment,
# restore a temporary media tree with the intended ownership, start Bazarr,
# and verify its local health endpoint.
#
# The drill deliberately excludes production Bazarr data, media, secrets,
# Restic repositories, external subtitle providers, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "bazarr-restore-drill";

  nodes.bazarr = { lib, ... }: {
    users.groups.media = { };

    users.users.bazarr = {
      isSystemUser = true;
      group = "bazarr";
      extraGroups = [ "media" ];
    };

    users.groups.bazarr = { };

    services.bazarr = {
      enable = true;
      dataDir = "/var/lib/bazarr-restore";
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /srv/media-restore 2775 root media -"
      "d /srv/media-restore/movies 2775 bazarr media -"
      "d /var/lib/bazarr-restore 0750 bazarr bazarr -"
      "d /var/lib/bazarr-restored 0750 bazarr bazarr -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    bazarr.start()
    bazarr.wait_for_unit("multi-user.target", timeout=120)
    bazarr.wait_for_unit("bazarr.service")
    bazarr.wait_for_open_port(6767)

    backup_root = "/tmp/bazarr-restore-drill"
    bazarr_backup = f"{backup_root}/bazarr"
    media_backup = f"{backup_root}/media"

    # The Bazarr service user needs to create its backup subdirectories.
    bazarr.succeed(
      "install -d -m 0775 -o root -g media " + shlex.quote(backup_root)
    )

    with subtest("Bazarr local health endpoint is available before backup"):
        bazarr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:6767/api/systemstatus"
        )

    with subtest("representative Bazarr state is backed up"):
        bazarr.succeed(
          "sudo -u bazarr install -d -m 0750 " + shlex.quote(bazarr_backup)
        )
        bazarr.succeed(
          "sudo -u bazarr install -d -m 0750 "
          + shlex.quote(f"{bazarr_backup}/config") + " "
          + shlex.quote(f"{bazarr_backup}/db")
        )

        config_probe = f"{bazarr_backup}/config/config.ini"
        database_probe = f"{bazarr_backup}/db/bazarr.db"

        bazarr.succeed(
          "sudo -u bazarr install -m 0640 /dev/null "
          + shlex.quote(config_probe)
        )
        bazarr.succeed(
          "sudo -u bazarr truncate -s 1 " + shlex.quote(config_probe)
        )

        bazarr.succeed(
          "sudo -u bazarr install -m 0640 /dev/null "
          + shlex.quote(database_probe)
        )
        bazarr.succeed(
          "sudo -u bazarr truncate -s 1 " + shlex.quote(database_probe)
        )

        bazarr.succeed(
          "sudo -u bazarr cp -a /var/lib/bazarr-restore/. "
          + shlex.quote(bazarr_backup) + "/"
        )

        bazarr.succeed(
          "sudo -u bazarr install -d -m 0750 " + shlex.quote(media_backup)
        )
        bazarr.succeed(
          "sudo -u bazarr install -m 0660 /dev/null "
          + shlex.quote(f"{media_backup}/movie")
        )

    with subtest("Bazarr state restores into an isolated directory"):
        bazarr.succeed(
          "sudo -u bazarr cp -a " + shlex.quote(bazarr_backup) + "/. "
          "/var/lib/bazarr-restored/"
        )

        bazarr.succeed(
          "sudo -u bazarr test -s /var/lib/bazarr-restored/config/config.ini"
        )
        bazarr.succeed(
          "sudo -u bazarr test -s /var/lib/bazarr-restored/db/bazarr.db"
        )

    with subtest("media tree restores with intended ownership"):
        bazarr.succeed(
          "install -d -m 2775 -o root -g media /srv/media-restored"
        )
        bazarr.succeed(
          "sudo -u bazarr install -d -m 2775 -o bazarr -g media "
          "/srv/media-restored/movies"
        )
        bazarr.succeed(
          "sudo -u bazarr cp " + shlex.quote(f"{media_backup}/movie") + " "
          "/srv/media-restored/movies/movie"
        )

        bazarr.succeed(
          "stat -c '%U %G' /srv/media-restored/movies/movie "
          "| grep -q 'bazarr media'"
        )
        bazarr.succeed(
          "sudo -u bazarr test -r /srv/media-restored/movies/movie"
        )

    with subtest("Bazarr starts against restored state"):
        # Restarting a system unit requires root; the Bazarr service user does
        # not have permission to manage systemd units.
        bazarr.succeed("systemctl restart bazarr.service")
        bazarr.wait_for_unit("bazarr.service")
        bazarr.wait_for_open_port(6767)

        bazarr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:6767/api/systemstatus"
        )

    with subtest("temporary recovery artifacts are removed"):
        bazarr.succeed("rm -rf -- /tmp/bazarr-restore-drill")
  '';
}
