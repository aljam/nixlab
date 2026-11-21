# Host rebuild recovery drill.
#
# Validates that a rebuilt host retains the recovery-critical configuration
# required before it can be promoted back into service: deployment access,
# SOPS recovery tooling, firewall policy, service enablement, and monitoring
# readiness.
#
# The drill is VM-only and deliberately excludes production deployment,
# production secrets, Restic repositories, external integrations, and public
# access.
{ pkgs }:

pkgs.testers.nixosTest {
  name = "host-rebuild-recovery-drill";

  nodes.rebuilt-host = { lib, ... }: {
    users.users.deploy = {
      isNormalUser = true;
      group = "deploy";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForHostRebuildRecoveryDrill"
      ];
    };

    users.groups.deploy = { };

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
      openFirewall = false;
    };

    environment.systemPackages = with pkgs; [
      curl
      jq
      sops
    ];
  };

  testScript = ''
    rebuilt_host.start()
    rebuilt_host.wait_for_unit("multi-user.target", timeout=120)

    with subtest("deployment access survives a host rebuild"):
        rebuilt_host.succeed("id deploy")
        rebuilt_host.succeed("systemctl is-active sshd.service")
        rebuilt_host.succeed(
          "test -s /etc/ssh/authorized_keys.d/deploy"
        )

    with subtest("SOPS recovery tooling is available"):
        rebuilt_host.succeed("command -v sops")
        rebuilt_host.succeed("sops --version")

    with subtest("firewall policy remains restrictive"):
        rebuilt_host.succeed("systemctl is-active nftables.service")
        rebuilt_host.succeed(
          "nft list ruleset | grep -q 'chain input'"
        )

    with subtest("monitoring exporter is enabled and healthy"):
        rebuilt_host.succeed(
          "systemctl is-active prometheus-node-exporter.service"
        )
        rebuilt_host.wait_for_open_port(9100)

        rebuilt_host.succeed(
          "curl --fail --silent --show-error --output /dev/null "
          "http://127.0.0.1:9100/metrics"
        )

    with subtest("temporary recovery artifacts are absent"):
        rebuilt_host.succeed(
          "test ! -e /tmp/host-rebuild-recovery-artifacts"
        )
  '';
}
