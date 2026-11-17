# Jellyfin restore drill.
#
# Validates the local recovery path: create a representative Jellyfin
# configuration/data backup and media-library state, restore both into an
# isolated environment, start Jellyfin, and verify its local public
# system-info API.
#
# The drill deliberately excludes production Jellyfin data, media, secrets,
# Restic repositories, transcoding, plugins, remote clients, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "jellyfin-restore-drill";

  nodes.jellyfin = { lib, ... }: {
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
      "d /var/lib/jellyfin-restore 0750 jellyfin jellyfin -"
      "d /var/lib/jellyfin-restore/data 0750 jellyfin jellyfin -"
      "d /var/lib/jellyfin-restore/config 0750 jellyfin jellyfin -"
      "d /var/lib/jellyfin-restore/cache 0750 jellyfin jellyfin -"
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

    backup_root = "/tmp/jellyfin-restore-drill"
    data_backup = f"{backup_root}/data"
    config_backup = f"{backup_root}/config"
    media_backup = f"{backup_root}/media"

    jellyfin.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Jellyfin local system API is available before backup"):
        output = jellyfin.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8096/System/Info/Public"
        )
        parsed = json.loads(output)
        assert parsed.get("Id"), output
        assert parsed.get("ServerName"), output

    with subtest("representative Jellyfin state is backed up"):
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
          "curl --fail --silent --show-error http://127.0.0.1:8096/System/Info/Public"
        )
        parsed = json.loads(output)
        assert parsed.get("Id"), output
        assert parsed.get("ServerName"), output

    with subtest("temporary recovery artifacts are removed"):
        jellyfin.succeed("rm -rf -- /tmp/jellyfin-restore-drill")
  '';
}
