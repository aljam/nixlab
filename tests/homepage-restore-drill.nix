# Homepage restore drill.
#
# Validates the local recovery path for Homepage: create a representative
# configuration backup, restore it into an isolated environment, start
# Homepage, and verify its local HTTP endpoint.
#
# The drill deliberately excludes production Homepage data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "homepage-restore-drill";

  nodes.homepage = { lib, ... }: {
    users.users.homepage = {
      isSystemUser = true;
      group = "homepage";
    };

    users.groups.homepage = { };

    services.homepage-dashboard = {
      enable = true;
      listenPort = 8082;
      openFirewall = false;

      settings = {
        title = "Restore Drill Homepage";
      };

      services = [
        {
          "Restore Drill" = [
            {
              "Local Service" = {
                icon = "mdi-home";
                href = "http://127.0.0.1:8082";
                description = "Local restore-drill service";
              };
            }
          ];
        }
      ];
    };

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    homepage.start()
    homepage.wait_for_unit("multi-user.target", timeout=120)
    homepage.wait_for_unit("homepage-dashboard.service")
    homepage.wait_for_open_port(8082)

    backup_root = "/tmp/homepage-restore-drill"
    homepage_backup = f"{backup_root}/homepage"

    homepage.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Homepage local endpoint is available before backup"):
        homepage.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8082"
        )

    with subtest("representative Homepage configuration is backed up"):
        homepage.succeed(
          "install -d -m 0750 " + shlex.quote(homepage_backup)
        )

        homepage.succeed(
          "install -m 0640 /etc/homepage-dashboard/settings.yaml "
          + shlex.quote(f"{homepage_backup}/settings.yaml")
        )
        homepage.succeed(
          "install -m 0640 /etc/homepage-dashboard/services.yaml "
          + shlex.quote(f"{homepage_backup}/services.yaml")
        )

    with subtest("Homepage configuration restores into an isolated directory"):
        homepage.succeed(
          "install -d -m 0750 /var/lib/homepage-restored"
        )

        homepage.succeed(
          "cp -a " + shlex.quote(homepage_backup) + "/. "
          "/var/lib/homepage-restored/"
        )

        homepage.succeed(
          "test -s /var/lib/homepage-restored/settings.yaml"
        )
        homepage.succeed(
          "test -s /var/lib/homepage-restored/services.yaml"
        )

    with subtest("Homepage starts against restored configuration"):
        homepage.succeed("systemctl restart homepage-dashboard.service")
        homepage.wait_for_unit("homepage-dashboard.service")
        homepage.wait_for_open_port(8082)

        homepage.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8082"
        )

    with subtest("temporary recovery artifacts are removed"):
        homepage.succeed("rm -rf -- /tmp/homepage-restore-drill")
  '';
}
