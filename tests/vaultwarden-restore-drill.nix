# Vaultwarden restore drill.
#
# Validates the local recovery path: create a representative Vaultwarden
# SQLite database and attachment state, restore both into an isolated
# environment, start Vaultwarden, and verify its local health/API endpoint.
#
# The drill deliberately excludes production Vaultwarden data, attachments,
# secrets, Restic repositories, public HTTPS access, and external integrations.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "vaultwarden-restore-drill";

  nodes.vaultwarden = { lib, ... }: {
    services.vaultwarden = {
      enable = true;

      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = "8222";
        SIGNUPS_ALLOWED = "false";
        DOMAIN = "http://127.0.0.1:8222";
        DATA_FOLDER = "/var/lib/vaultwarden-restore/data";
        ATTACHMENTS_FOLDER = "/var/lib/vaultwarden-restore/attachments";
        ADMIN_RATELIMIT_SECONDS = "60";
        ADMIN_RATELIMIT_MAX_BURST = "3";
      };
    };

    users.users.vaultwarden.extraGroups = [ "vaultwarden-restore" ];
    users.groups.vaultwarden-restore = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/vaultwarden-restore 0750 vaultwarden vaultwarden-restore -"
      "d /var/lib/vaultwarden-restore/data 0750 vaultwarden vaultwarden-restore -"
      "d /var/lib/vaultwarden-restore/attachments 0750 vaultwarden vaultwarden-restore -"
    ];

    environment.systemPackages = with pkgs; [
      curl
      jq
      sqlite
    ];
  };

  testScript = ''
    import json
    import shlex

    vaultwarden.start()
    vaultwarden.wait_for_unit("vaultwarden.service")
    vaultwarden.wait_for_open_port(8222)

    backup_root = "/tmp/vaultwarden-restore-drill"
    database_backup = f"{backup_root}/db.sqlite3"
    attachments_backup = f"{backup_root}/attachments"

    vaultwarden.succeed(
      "install -d -m 0700 -o vaultwarden -g vaultwarden-restore "
      + shlex.quote(backup_root)
    )

    with subtest("Vaultwarden local API is available before backup"):
        output = vaultwarden.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8222/alive"
        )
        assert json.loads(output).get("status") == "alive", output

    with subtest("representative Vaultwarden state is backed up"):
        vaultwarden.succeed(
          "sudo -u vaultwarden sqlite3 "
          "/var/lib/vaultwarden-restore/data/db.sqlite3 "
          "'CREATE TABLE restore_probe (id INTEGER PRIMARY KEY, label TEXT); "
          "INSERT INTO restore_probe VALUES (1, \'restore-drill\');'"
        )
        vaultwarden.succeed(
          "sudo -u vaultwarden sqlite3 "
          "/var/lib/vaultwarden-restore/data/db.sqlite3 "
          "'.backup ' + shlex.quote(database_backup)
        )
        vaultwarden.succeed("test -s " + shlex.quote(database_backup))

        vaultwarden.succeed(
          "sudo -u vaultwarden install -d -m 0750 "
          + shlex.quote(attachments_backup)
        )
        vaultwarden.succeed(
          "sudo -u vaultwarden install -m 0640 /dev/null "
          + shlex.quote(f"{attachments_backup}/restore-probe")
        )

    with subtest("Vaultwarden state restores into an isolated environment"):
        vaultwarden.succeed(
          "sudo -u vaultwarden install -d -m 0750 "
          "/var/lib/vaultwarden-restore/restored-data "
          "/var/lib/vaultwarden-restore/restored-attachments"
        )
        vaultwarden.succeed(
          "sudo -u vaultwarden cp "
          + shlex.quote(database_backup)
          + " /var/lib/vaultwarden-restore/restored-data/db.sqlite3"
        )
        vaultwarden.succeed(
          "sudo -u vaultwarden cp -a "
          + shlex.quote(attachments_backup)
          + "/. /var/lib/vaultwarden-restore/restored-attachments/"
        )

        output = vaultwarden.succeed(
          "sudo -u vaultwarden sqlite3 "
          "/var/lib/vaultwarden-restore/restored-data/db.sqlite3 "
          "'SELECT label FROM restore_probe WHERE id = 1'"
        )
        assert output.strip() == "restore-drill", output

    with subtest("restored attachments have the intended ownership"):
        vaultwarden.succeed(
          "stat -c '%U %G' "
          "/var/lib/vaultwarden-restore/restored-attachments/restore-probe "
          "| grep -q 'vaultwarden vaultwarden-restore'"
        )

    with subtest("Vaultwarden starts against restored state"):
        vaultwarden.succeed(
          "sudo -u vaultwarden systemctl restart vaultwarden.service"
        )
        vaultwarden.wait_for_unit("vaultwarden.service")
        vaultwarden.wait_for_open_port(8222)

        output = vaultwarden.succeed(
          "curl --fail --silent --show-error http://127.0.0.1:8222/alive"
        )
        assert json.loads(output).get("status") == "alive", output

    with subtest("temporary recovery artifacts are removed"):
        vaultwarden.succeed("rm -rf -- /tmp/vaultwarden-restore-drill")
  '';
}
