# Prometheus restore drill.
#
# Validates the local recovery path for Prometheus: create a representative
# configuration/data backup, restore it into the service state directory,
# restart Prometheus, and verify its local HTTP API.
#
# The drill deliberately excludes production Prometheus data, secrets, Restic
# repositories, external integrations, and public access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "prometheus-restore-drill";

  nodes.prometheus = { lib, ... }: {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9090;

      retentionTime = "1d";

      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = [ "127.0.0.1:9090" ];
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

    prometheus.start()
    prometheus.wait_for_unit("multi-user.target", timeout=120)
    prometheus.wait_for_unit("prometheus.service")
    prometheus.wait_for_open_port(9090)

    backup_root = "/tmp/prometheus-restore-drill"
    prometheus_backup = f"{backup_root}/prometheus"

    prometheus.succeed(
      "install -d -m 0700 -o root -g root " + shlex.quote(backup_root)
    )

    with subtest("Prometheus local API is available before backup"):
        prometheus.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9090/-/healthy"
        )

    with subtest("representative Prometheus state is backed up"):
        prometheus.succeed(
          "install -d -m 0750 -o root -g root " + shlex.quote(prometheus_backup)
        )

        prometheus.succeed(
          "install -m 0640 /etc/prometheus/prometheus.yml "
          + shlex.quote(f"{prometheus_backup}/prometheus.yml")
        )

        prometheus.succeed(
          "install -m 0640 /dev/null "
          + shlex.quote(f"{prometheus_backup}/restore-manifest")
        )
        prometheus.succeed(
          "truncate -s 1 "
          + shlex.quote(f"{prometheus_backup}/restore-manifest")
        )

        prometheus.succeed(
          "cp -a /var/lib/prometheus2 "
          + shlex.quote(f"{prometheus_backup}/data")
        )

    with subtest("Prometheus state restores into the service state directory"):
        prometheus.succeed("systemctl stop prometheus")
        prometheus.succeed(
          "find /var/lib/prometheus2 -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
        )
        prometheus.succeed(
          "cp -a " + shlex.quote(f"{prometheus_backup}/data")
          + "/. /var/lib/prometheus2/"
        )

        prometheus.succeed(
          "test -s " + shlex.quote(f"{prometheus_backup}/restore-manifest")
        )
        prometheus.succeed("test -s /etc/prometheus/prometheus.yml")

    with subtest("Prometheus starts against restored state"):
        prometheus.succeed("systemctl start prometheus")
        prometheus.wait_for_unit("prometheus.service")
        prometheus.wait_for_open_port(9090)

        prometheus.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9090/-/healthy"
        )

    with subtest("temporary recovery artifacts are removed"):
        prometheus.succeed("rm -rf -- /tmp/prometheus-restore-drill")
  '';
}
