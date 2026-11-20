# Radio restore drill.
#
# Validates recovery of the Icecast component of the radio stack. Icecast's
# configuration is declaratively generated, so this drill captures the active
# configuration, restarts the service, and verifies that the same configuration
# remains available and the local status endpoint recovers.
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

    with subtest("Icecast local status endpoint is available before recovery"):
        radio.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8000/status.xsl"
        )

    with subtest("active Icecast configuration is captured"):
        radio.succeed(
          "config=\"$(systemctl show icecast --property=ExecStart --value "
          "| awk '{print $NF}')\"; test -n \"$config\"; test -s \"$config\"; "
          "cp -a \"$config\" " + shlex.quote(config_backup)
        )
        radio.succeed(
          "test -s " + shlex.quote(config_backup)
        )

    with subtest("Icecast service recovers with its declarative configuration"):
        radio.succeed("systemctl restart icecast")
        radio.wait_for_unit("icecast.service")
        radio.wait_for_open_port(8000)

        radio.succeed(
          "config=\"$(systemctl show icecast --property=ExecStart --value "
          "| awk '{print $NF}')\"; "
          "sha256sum \"$config\" " + shlex.quote(config_backup) +
          " | awk 'NR==1 {a=$1} NR==2 {b=$1} END {exit a==b ? 0 : 1}'"
        )

        radio.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:8000/status.xsl"
        )

    with subtest("temporary recovery artifacts are removed"):
        radio.succeed("rm -rf -- /tmp/radio-restore-drill")
  '';
}
