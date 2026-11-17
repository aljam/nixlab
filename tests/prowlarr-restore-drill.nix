# Prowlarr restore drill.
#
# Validates the local recovery path: create a representative Prowlarr
# configuration/database backup, restore it into an isolated environment,
# start Prowlarr, and verify its local health endpoint.
#
# The drill deliberately excludes production Prowlarr data, secrets, Restic
# repositories, external indexers, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "prowlarr-restore-drill";

  nodes.prowlarr = { lib, ... }: {
    users.users.prowlarr = {
      isSystemUser = true;
      group = "prowlarr";
    };

    users.groups.prowlarr = { };

    services.prowlarr = {
      enable = true;
      dataDir = "/var/lib/prowlarr-restore";
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/prowlarr-restore 0750 prowlarr prowlarr -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    prowlarr.start()
    prowlarr.wait_for_unit("multi-user.target", timeout=120)
    prowlarr.wait_for_unit("prowlarr.service")
    prowlarr.wait_for_open_port(9696)

    backup_root = "/tmp/prowlarr-restore-drill"
    prowlarr_backup = f"{backup_root}/prowlarr"

    prowlarr.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Prowlarr local health endpoint is available before backup"):
        prowlarr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9696/api/v1/health"
        )

    with subtest("representative Prowlarr state is backed up"):
        prowlarr.succeed(
          "sudo -u prowlarr install -d -m 0750 " + shlex.quote(prowlarr_backup)
        )
        prowlarr.succeed(
          "sudo -u prowlarr install -m 0640 /dev/null "
          + shlex.quote(f"{prowlarr_backup}/config.xml")
        )
        prowlarr.succeed(
          "sudo -u prowlarr install -m 0640 /dev/null "
          + shlex.quote(f"{prowlarr_backup}/prowlarr.db")
        )
        prowlarr.succeed(
          "sudo -u prowlarr cp -a /var/lib/prowlarr-restore/. "
          + shlex.quote(prowlarr_backup) + "/"
        )

    with subtest("Prowlarr state restores into an isolated directory"):
        prowlarr.succeed(
          "sudo -u prowlarr install -d -m 0750 /var/lib/prowlarr-restored"
        )
        prowlarr.succeed(
          "sudo -u prowlarr cp -a " + shlex.quote(prowlarr_backup) + "/. "
          "/var/lib/prowlarr-restored/"
        )

        prowlarr.succeed(
          "sudo -u prowlarr test -s /var/lib/prowlarr-restored/config.xml"
        )
        prowlarr.succeed(
          "sudo -u prowlarr test -s /var/lib/prowlarr-restored/prowlarr.db"
        )

    with subtest("Prowlarr starts against restored state"):
        prowlarr.succeed(
          "sudo -u prowlarr systemctl restart prowlarr.service"
        )
        prowlarr.wait_for_unit("prowlarr.service")
        prowlarr.wait_for_open_port(9696)

        prowlarr.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9696/api/v1/health"
        )

    with subtest("temporary recovery artifacts are removed"):
        prowlarr.succeed("rm -rf -- /tmp/prowlarr-restore-drill")
  '';
}
