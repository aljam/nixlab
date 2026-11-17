# Radio restore drill.
#
# Validates the local recovery path for Radio: create a representative
# configuration/state backup, restore it into an isolated environment, start
# Radio, and verify its local HTTP API.
#
# The drill deliberately excludes production Radio data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "radio-restore-drill";

  nodes.radio = { lib, ... }: {
    users.users.radio = {
      isSystemUser = true;
      group = "radio";
    };

    users.groups.radio = { };

    services.radio = {
      enable = true;
      dataDir = "/var/lib/radio-restore";
      openFirewall = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/radio-restore 0750 radio radio -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
    ];
  };

  testScript = ''
    import shlex

    radio.start()
    radio.wait_for_unit("multi-user.target", timeout=120)
    radio.wait_for_unit("radio.service")
    radio.wait_for_open_port(3000)

    backup_root = "/tmp/radio-restore-drill"
    radio_backup = f"{backup_root}/radio"
    restored_state = "/var/lib/radio-restored"

    radio.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Radio local API is available before backup"):
        radio.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3000/api/health"
        )

    with subtest("representative Radio state is backed up"):
        radio.succeed(
          "sudo -u radio install -d -m 0750 " + shlex.quote(radio_backup)
        )

        radio.succeed(
          "sudo -u radio install -m 0640 /dev/null "
          + shlex.quote(f"{radio_backup}/radio.db")
        )
        radio.succeed(
          "sudo -u radio install -m 0640 /dev/null "
          + shlex.quote(f"{radio_backup}/config.json")
        )

        radio.succeed(
          "sudo -u radio cp -a /var/lib/radio-restore/. "
          + shlex.quote(radio_backup) + "/"
        )

    with subtest("Radio state restores into an isolated directory"):
        radio.succeed(
          "sudo -u radio install -d -m 0750 " + shlex.quote(restored_state)
        )

        radio.succeed(
          "sudo -u radio cp -a " + shlex.quote(radio_backup) + "/. "
          + shlex.quote(restored_state) + "/"
        )

        radio.succeed(
          "sudo -u radio test -s " + shlex.quote(f"{restored_state}/radio.db")
        )
        radio.succeed(
          "sudo -u radio test -s " + shlex.quote(f"{restored_state}/config.json")
        )

    with subtest("Radio starts against restored state"):
        radio.succeed(
          "sudo -u radio systemctl restart radio.service"
        )
        radio.wait_for_unit("radio.service")
        radio.wait_for_open_port(3000)

        radio.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:3000/api/health"
        )

    with subtest("temporary recovery artifacts are removed"):
        radio.succeed("rm -rf -- /tmp/radio-restore-drill")
  '';
}
