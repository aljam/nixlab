# Jellyfin restore drill.
#
# Validates the local recovery path: create a representative Jellyfin
# configuration/data backup and media-library state, restore both into an
# isolated environment, start Jellyfin from the restored state, and verify its
# local health endpoint.
#
# The drill deliberately excludes production Jellyfin data, media, secrets,
# Restic repositories, transcoding, plugins, remote clients, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "jellyfin-restore-drill";

  nodes.jellyfin = { lib, ... }: {
    virtualisation.diskSize = 8192;

    users.groups.media = { };

    users.users.jellyfin.extraGroups = [ "media" ];

    services.jellyfin = {
      enable = true;
      group = "media";
      dataDir = "/var/lib/jellyfin-restore/data";
      configDir = "/var/lib/jellyfin-restore/config";
      cacheDir = "/var/lib/jellyfin-restore/cache";
    };

    systemd.tmpfiles.rules = [
      "d /srv/jellyfin-restore 2775 root media -"
      "d /srv/jellyfin-restore/movies 2775 jellyfin media -"
      "d /var/lib/jellyfin-restore 0750 jellyfin media -"
      "d /var/lib/jellyfin-restore/data 0750 jellyfin media -"
      "d /var/lib/jellyfin-restore/config 0750 jellyfin media -"
      "d /var/lib/jellyfin-restore/cache 0750 jellyfin media -"
      "d /var/lib/jellyfin-restored 0750 jellyfin media -"
      "d /var/lib/jellyfin-restored/data 0750 jellyfin media -"
      "d /var/lib/jellyfin-restored/config 0750 jellyfin media -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import json
    import shlex

    jellyfin.start()
    jellyfin.wait_for_unit("multi-user.target", timeout=120)
    jellyfin.wait_for_unit("jellyfin.service")
    jellyfin.wait_for_open_port(8096)

    # Jellyfin opens its HTTP listener before it is fully ready to serve
    # requests. The health endpoint verifies both HTTP and database
    # connectivity, so use it rather than treating an open TCP port as ready.
    jellyfin.wait_until_succeeds(
      "curl --fail --silent --show-error http://127.0.0.1:8096/health",
      timeout=120,
    )

    _, journal = jellyfin.execute(
      "journalctl -u jellyfin --no-pager -n 200"
    )
    print(journal)

    backup_root = "/tmp/jellyfin-restore-drill"
    data_backup = f"{backup_root}/data"
    config_backup = f"{backup_root}/config"
    media_backup = f"{backup_root}/media"

    jellyfin.succeed(
      "install -d -m 0700 -o jellyfin -g media " + shlex.quote(backup_root)
    )

    with subtest("Jellyfin local system API is available before backup"):
        output = jellyfin.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8096/System/Info/Public"
        )
        parsed = json.loads(output)
        assert parsed.get("id"), output
        assert parsed.get("serverName"), output

    with subtest("representative Jellyfin state is backed up"):
        # Stop Jellyfin before copying its state so the backup captures a
        # consistent configuration and SQLite database state.
        jellyfin.succeed("systemctl stop jellyfin")
        jellyfin.wait_for_unit_state("jellyfin.service", "inactive")

        jellyfin.succeed(
          "sudo -u jellyfin install -d -m 0750 "
          + shlex.quote(data_backup) + " "
          + shlex.quote(config_backup) + " "
          + shlex.quote(media_backup)
        )

        jellyfin.succeed(
          "sudo -u jellyfin cp -a /var/lib/jellyfin-restore/data/. "
          + shlex.quote(data_backup) + "/"
        )
        jellyfin.succeed(
          "sudo -u jellyfin cp -a /var/lib/jellyfin-restore/config/. "
          + shlex.quote(config_backup) + "/"
        )

        jellyfin.succeed(
          "sudo -u jellyfin install -m 0660 /dev/null "
          + shlex.quote(f"{media_backup}/movie")
        )

    with subtest("Jellyfin state restores into an isolated environment"):
        jellyfin.succeed(
          "sudo -u jellyfin install -d -m 0750 "
          "/var/lib/jellyfin-restored/data "
          "/var/lib/jellyfin-restored/config"
        )

        jellyfin.succeed(
          "sudo -u jellyfin cp -a " + shlex.quote(data_backup) + "/. "
          "/var/lib/jellyfin-restored/data/"
        )
        jellyfin.succeed(
          "sudo -u jellyfin cp -a " + shlex.quote(config_backup) + "/. "
          "/var/lib/jellyfin-restored/config/"
        )

        jellyfin.succeed(
          "sudo -u jellyfin test -d /var/lib/jellyfin-restored/data"
        )
        jellyfin.succeed(
          "sudo -u jellyfin test -d /var/lib/jellyfin-restored/config"
        )

    with subtest("Jellyfin starts from the restored state"):
        # Replace the active state with the restored copy, then start Jellyfin
        # against it. This validates that the restored configuration and
        # database can boot, rather than only checking that files were copied.
        jellyfin.succeed(
          "mv /var/lib/jellyfin-restore/data "
          "/var/lib/jellyfin-restore/data.pre-restore"
        )
        jellyfin.succeed(
          "mv /var/lib/jellyfin-restore/config "
          "/var/lib/jellyfin-restore/config.pre-restore"
        )
        jellyfin.succeed(
          "mv /var/lib/jellyfin-restored/data /var/lib/jellyfin-restore/data"
        )
        jellyfin.succeed(
          "mv /var/lib/jellyfin-restored/config "
          "/var/lib/jellyfin-restore/config"
        )

        jellyfin.succeed(
          "chown -R jellyfin:media /var/lib/jellyfin-restore/data "
          "/var/lib/jellyfin-restore/config"
        )

        jellyfin.succeed("systemctl start jellyfin")
        jellyfin.wait_for_unit("jellyfin.service")
        jellyfin.wait_for_open_port(8096)

        jellyfin.wait_until_succeeds(
          "curl --fail --silent --show-error http://127.0.0.1:8096/health",
          timeout=180,
        )

    with subtest("media library restores with intended ownership"):
        jellyfin.succeed(
          "install -d -m 2775 -o root -g media /srv/jellyfin-restored"
        )
        jellyfin.succeed(
          "sudo -u jellyfin install -d -m 2775 -o jellyfin -g media "
          "/srv/jellyfin-restored/movies"
        )
        jellyfin.succeed(
          "sudo -u jellyfin cp " + shlex.quote(f"{media_backup}/movie") + " "
          "/srv/jellyfin-restored/movies/movie"
        )

        jellyfin.succeed(
          "stat -c '%U %G' /srv/jellyfin-restored/movies/movie "
          "| grep -q 'jellyfin media'"
        )
        jellyfin.succeed(
          "sudo -u jellyfin test -r /srv/jellyfin-restored/movies/movie"
        )

    with subtest("Jellyfin remains healthy after restore validation"):
        output = jellyfin.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8096/health"
        )

    with subtest("temporary recovery artifacts are removed"):
        jellyfin.succeed("rm -rf -- /tmp/jellyfin-restore-drill")
  '';
}
