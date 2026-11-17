# Lidarr restore drill.
#
# Validates the local recovery path: create a representative Lidarr
# configuration/state backup, restore it into an isolated environment,
# restore a temporary music-library tree with the intended ownership,
# start Lidarr, and verify its local HTTP API.
#
# The drill deliberately excludes production Lidarr data, music, secrets,
# Restic repositories, external indexers, download clients, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "lidarr-restore-drill";

  nodes.lidarr = { lib, ... }: {
    users.groups.media = { };

    users.users.lidarr = {
      isSystemUser = true;
      group = "lidarr";
      extraGroups = [ "media" ];
    };

    users.groups.lidarr = { };

    services.lidarr = {
      enable = true;
      dataDir = "/var/lib/lidarr-restore";
    };

    systemd.tmpfiles.rules = [
      "d /srv/music-restore 2775 root media -"
      "d /srv/music-restore/albums 2775 lidarr media -"
      "d /var/lib/lidarr-restore 0750 lidarr lidarr -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    lidarr.start()
    lidarr.wait_for_unit("multi-user.target", timeout=120)
    lidarr.wait_for_unit("lidarr.service")
    lidarr.wait_for_open_port(8686)

    backup_root = "/tmp/lidarr-restore-drill"
    lidarr_backup = f"{backup_root}/lidarr"
    music_backup = f"{backup_root}/music"

    lidarr.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Lidarr local API is available before backup"):
        lidarr.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8686/api/v1/system/status"
          " | jq -e 'has(\"version\")'"
        )

    with subtest("representative Lidarr state is backed up"):
        lidarr.succeed(
          "sudo -u lidarr install -d -m 0750 " + shlex.quote(lidarr_backup)
        )
        lidarr.succeed(
          "sudo -u lidarr install -m 0640 /dev/null "
          + shlex.quote(f"{lidarr_backup}/config.xml")
        )
        lidarr.succeed(
          "sudo -u lidarr cp -a /var/lib/lidarr-restore/. "
          + shlex.quote(lidarr_backup) + "/"
        )

        lidarr.succeed(
          "sudo -u lidarr install -d -m 0750 " + shlex.quote(music_backup)
        )
        lidarr.succeed(
          "sudo -u lidarr install -m 0660 /dev/null "
          + shlex.quote(f"{music_backup}/album")
        )

    with subtest("Lidarr state restores into an isolated directory"):
        lidarr.succeed(
          "sudo -u lidarr install -d -m 0750 /var/lib/lidarr-restored"
        )
        lidarr.succeed(
          "sudo -u lidarr cp -a " + shlex.quote(lidarr_backup) + "/. "
          "/var/lib/lidarr-restored/"
        )

        lidarr.succeed(
          "sudo -u lidarr test -s /var/lib/lidarr-restored/config.xml"
        )

    with subtest("music library restores with intended ownership"):
        lidarr.succeed(
          "install -d -m 2775 -o root -g media /srv/music-restored"
        )
        lidarr.succeed(
          "sudo -u lidarr install -d -m 2775 -o lidarr -g media "
          "/srv/music-restored/albums"
        )
        lidarr.succeed(
          "sudo -u lidarr cp " + shlex.quote(f"{music_backup}/album") + " "
          "/srv/music-restored/albums/album"
        )

        lidarr.succeed(
          "stat -c '%U %G' /srv/music-restored/albums/album "
          "| grep -q 'lidarr media'"
        )
        lidarr.succeed(
          "sudo -u lidarr test -r /srv/music-restored/albums/album"
        )

    with subtest("Lidarr remains healthy after restore validation"):
        lidarr.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8686/api/v1/system/status"
          " | jq -e 'has(\"version\")'"
        )

    with subtest("temporary recovery artifacts are removed"):
        lidarr.succeed("rm -rf -- /tmp/lidarr-restore-drill")
  '';
}
