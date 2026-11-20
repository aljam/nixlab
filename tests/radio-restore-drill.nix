# Radio restore drill.
#
# Validates the Icecast component of the radio stack: back up its generated
# configuration, restore it, restart Icecast, and verify its local status
# endpoint.
#
# The drill deliberately excludes production music, streaming credentials,
# Liquidsoap integration, external listeners, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "radio-restore-drill";

  nodes.radio = { lib, ... }: {
    services.icecast = {
      enable = true;
      hostname = "localhost";
      listen.address = "127.0.0.1";
      admin.password = "unused-by-test";
    };

    environment.systemPackages = with pkgs; [
      curl
    ];
  };

  testScript = ''
    import shlex

    radio.start()
    radio.wait_for_unit("multi-user.target", timeout=120)
    radio.wait_for_unit("icecast.service")
    radio.wait_for_open_port(8000)

    backup_root = "/tmp/radio-restore-drill"
    config_backup = f"{backup_root}/icecast.xml"

    radio.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Icecast local status endpoint is available before backup"):
        radio.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8000/status.xsl"
        )

    with subtest("representative Icecast configuration is backed up"):
        radio.succeed(
          "cp -a /etc/icecast.xml " + shlex.quote(config_backup)
        )
        radio.succeed(
          "test -s " + shlex.quote(config_backup)
        )

    with subtest("Icecast configuration restores and service restarts"):
        radio.succeed("systemctl stop icecast")
        radio.succeed("rm -f /etc/icecast.xml")
        radio.succeed(
          "cp -a " + shlex.quote(config_backup) + " /etc/icecast.xml"
        )
        radio.succeed("systemctl start icecast")
        radio.wait_for_unit("icecast.service")
        radio.wait_for_open_port(8000)

        radio.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8000/status.xsl"
        )

    with subtest("temporary recovery artifacts are removed"):
        radio.succeed("rm -rf -- /tmp/radio-restore-drill")
  '';
}
