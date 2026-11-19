# qBittorrent restore drill.
#
# Validates the local recovery path: create a representative qBittorrent
# configuration and torrent-state backup, restore it into an isolated
# environment, start qBittorrent, and verify its local WebUI.
#
# The drill deliberately excludes production qBittorrent data, downloads,
# secrets, Restic repositories, external trackers, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "qbittorrent-restore-drill";

  nodes.qbittorrent = { lib, ... }: {
    services.qbittorrent = {
      enable = true;
      webuiPort = 8080;
    };

    systemd.tmpfiles.rules = [
      "d /srv/qbittorrent-restore 2775 qbittorrent qbittorrent -"
      "d /srv/qbittorrent-restore/downloads 2775 qbittorrent qbittorrent -"
      "d /var/lib/qbittorrent 0750 qbittorrent qbittorrent -"
      "d /var/lib/qbittorrent-restored 0750 qbittorrent qbittorrent -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    qbittorrent.start()
    qbittorrent.wait_for_unit("qbittorrent.service")
    qbittorrent.wait_for_open_port(8080)

    backup_root = "/tmp/qbittorrent-restore-drill"
    config_backup = f"{backup_root}/config"
    torrent_backup = f"{backup_root}/BT_backup"

    qbittorrent.succeed(
      "install -d -m 0700 -o qbittorrent -g qbittorrent "
      + shlex.quote(backup_root)
    )

    with subtest("qBittorrent local WebUI is available before backup"):
        qbittorrent.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8080/"
        )

    with subtest("representative qBittorrent state is backed up"):
        qbittorrent.succeed(
          "sudo -u qbittorrent install -d -m 0750 "
          + shlex.quote(config_backup) + " "
          + shlex.quote(torrent_backup)
        )

        qbittorrent.succeed(
          "sudo -u qbittorrent cp -a /var/lib/qbittorrent/. "
          + shlex.quote(config_backup) + "/"
        )

        qbittorrent.succeed(
          "sudo -u qbittorrent install -m 0640 /dev/null "
          + shlex.quote(f"{torrent_backup}/restore-probe.fastresume")
        )
        qbittorrent.succeed(
          "sudo -u qbittorrent install -m 0640 /dev/null "
          + shlex.quote(f"{torrent_backup}/restore-probe.torrent")
        )

    with subtest("qBittorrent state restores into an isolated environment"):
        qbittorrent.succeed(
          "install -d -m 0750 -o qbittorrent -g qbittorrent "
          "/var/lib/qbittorrent-restored"
        )
        qbittorrent.succeed(
          "sudo -u qbittorrent cp -a " + shlex.quote(config_backup) + "/. "
          "/var/lib/qbittorrent-restored/"
        )

        qbittorrent.succeed(
          "sudo -u qbittorrent install -d -m 0750 "
          "/var/lib/qbittorrent-restored/BT_backup"
        )
        qbittorrent.succeed(
          "sudo -u qbittorrent cp -a " + shlex.quote(torrent_backup) + "/. "
          "/var/lib/qbittorrent-restored/BT_backup/"
        )

        qbittorrent.succeed(
          "sudo -u qbittorrent test -s "
          "/var/lib/qbittorrent-restored/BT_backup/restore-probe.fastresume"
        )
        qbittorrent.succeed(
          "sudo -u qbittorrent test -s "
          "/var/lib/qbittorrent-restored/BT_backup/restore-probe.torrent"
        )

    with subtest("qBittorrent starts against restored state"):
        qbittorrent.succeed(
          "sudo -u qbittorrent systemctl restart qbittorrent.service"
        )
        qbittorrent.wait_for_unit("qbittorrent.service")
        qbittorrent.wait_for_open_port(8080)

        qbittorrent.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8080/"
        )

    with subtest("temporary recovery artifacts are removed"):
        qbittorrent.succeed("rm -rf -- /tmp/qbittorrent-restore-drill")
  '';
}
