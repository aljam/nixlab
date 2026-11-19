# Sonarr/Radarr restore drill.
#
# Validates the local recovery path for the two primary Servarr services:
# create Sonarr and Radarr configuration/state backups, restore them into
# isolated service state directories, restore a temporary shared media tree
# with the intended ownership, start both services, and verify their local
# HTTP APIs.
#
# The drill deliberately excludes production media, download state, secrets,
# Restic repositories, external indexers, download clients, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "sonarr-radarr-restore-drill";

  nodes.media = { lib, ... }: {
    users.groups.media = { };

    users.users = {
      radarr = {
        isSystemUser = true;
        group = "radarr";
        extraGroups = [ "media" ];
      };

      sonarr = {
        isSystemUser = true;
        group = "sonarr";
        extraGroups = [ "media" ];
      };
    };

    users.groups.radarr = { };
    users.groups.sonarr = { };

    services.radarr = {
      enable = true;
      dataDir = "/var/lib/radarr-restore";
    };

    services.sonarr = {
      enable = true;
      dataDir = "/var/lib/sonarr-restore";
    };

    systemd.tmpfiles.rules = [
      "d /srv/media-restore 2775 root media -"
      "d /srv/media-restore/movies 2775 radarr media -"
      "d /srv/media-restore/tv 2775 sonarr media -"
      "d /var/lib/radarr-restore 0750 radarr radarr -"
      "d /var/lib/sonarr-restore 0750 sonarr sonarr -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    def servarr_status(port, api_key):
        return (
          "curl --fail --silent --show-error -H "
          + shlex.quote(f"X-Api-Key: {api_key}")
          + f" http://127.0.0.1:{port}/api/v3/system/status"
          + " | jq -e 'has(\"version\")'"
        )

    media.start()
    media.wait_for_unit("multi-user.target", timeout=120)

    backup_root = "/tmp/sonarr-radarr-restore-drill"
    radarr_backup = f"{backup_root}/radarr"
    sonarr_backup = f"{backup_root}/sonarr"
    media_backup = f"{backup_root}/media"

    media.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Radarr and Sonarr local APIs are available before backup"):
        media.wait_for_unit("radarr.service")
        media.wait_for_unit("sonarr.service")
        media.wait_for_open_port(7878)
        media.wait_for_open_port(8989)

        radarr_api_key = media.succeed(
          "grep -o '<ApiKey>[^<]*' /var/lib/radarr-restore/config.xml "
          "| cut -d '>' -f2"
        ).strip()
        sonarr_api_key = media.succeed(
          "grep -o '<ApiKey>[^<]*' /var/lib/sonarr-restore/config.xml "
          "| cut -d '>' -f2"
        ).strip()

        media.wait_until_succeeds(
          servarr_status(7878, radarr_api_key), timeout=180
        )
        media.wait_until_succeeds(
          servarr_status(8989, sonarr_api_key), timeout=180
        )

    with subtest("representative Radarr and Sonarr state is backed up"):
        media.succeed(
          "sudo -u radarr install -d -m 0750 " + shlex.quote(radarr_backup)
        )
        media.succeed(
          "sudo -u radarr install -m 0640 /dev/null "
          + shlex.quote(f"{radarr_backup}/config.xml")
        )
        media.succeed(
          "sudo -u radarr cp -a /var/lib/radarr-restore/. "
          + shlex.quote(radarr_backup) + "/"
        )

        media.succeed(
          "sudo -u sonarr install -d -m 0750 " + shlex.quote(sonarr_backup)
        )
        media.succeed(
          "sudo -u sonarr install -m 0640 /dev/null "
          + shlex.quote(f"{sonarr_backup}/config.xml")
        )
        media.succeed(
          "sudo -u sonarr cp -a /var/lib/sonarr-restore/. "
          + shlex.quote(sonarr_backup) + "/"
        )

        media.succeed(
          "sudo -u radarr install -d -m 0750 " + shlex.quote(media_backup)
        )
        media.succeed(
          "sudo -u radarr install -m 0660 /dev/null "
          + shlex.quote(f"{media_backup}/movie")
        )
        media.succeed(
          "sudo -u sonarr install -m 0660 /dev/null "
          + shlex.quote(f"{media_backup}/episode")
        )

    with subtest("Radarr and Sonarr state restores into isolated directories"):
        media.succeed(
          "sudo -u radarr install -d -m 0750 /var/lib/radarr-restored"
        )
        media.succeed(
          "sudo -u radarr cp -a " + shlex.quote(radarr_backup) + "/. "
          "/var/lib/radarr-restored/"
        )

        media.succeed(
          "sudo -u sonarr install -d -m 0750 /var/lib/sonarr-restored"
        )
        media.succeed(
          "sudo -u sonarr cp -a " + shlex.quote(sonarr_backup) + "/. "
          "/var/lib/sonarr-restored/"
        )

        media.succeed(
          "sudo -u radarr test -s /var/lib/radarr-restored/config.xml"
        )
        media.succeed(
          "sudo -u sonarr test -s /var/lib/sonarr-restored/config.xml"
        )

    with subtest("shared media tree restores with intended ownership"):
        media.succeed(
          "install -d -m 2775 -o root -g media /srv/media-restored"
        )
        media.succeed(
          "sudo -u radarr install -d -m 2775 -o radarr -g media "
          "/srv/media-restored/movies"
        )
        media.succeed(
          "sudo -u sonarr install -d -m 2775 -o sonarr -g media "
          "/srv/media-restored/tv"
        )

        media.succeed(
          "sudo -u radarr cp " + shlex.quote(f"{media_backup}/movie") + " "
          "/srv/media-restored/movies/movie"
        )
        media.succeed(
          "sudo -u sonarr cp " + shlex.quote(f"{media_backup}/episode") + " "
          "/srv/media-restored/tv/episode"
        )

        media.succeed(
          "stat -c '%U %G' /srv/media-restored/movies/movie "
          "| grep -q 'radarr media'"
        )
        media.succeed(
          "stat -c '%U %G' /srv/media-restored/tv/episode "
          "| grep -q 'sonarr media'"
        )

        media.succeed(
          "sudo -u radarr test -r /srv/media-restored/tv/episode"
        )
        media.succeed(
          "sudo -u sonarr test -r /srv/media-restored/movies/movie"
        )

    with subtest("Radarr and Sonarr remain healthy after restore validation"):
        media.succeed(servarr_status(7878, radarr_api_key))
        media.succeed(servarr_status(8989, sonarr_api_key))

    with subtest("temporary recovery artifacts are removed"):
        media.succeed("rm -rf -- /tmp/sonarr-radarr-restore-drill")
  '';
}
