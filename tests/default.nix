# NixOS tests for critical services
# Run with: nix-build tests/default.nix

{
  pkgs ? import <nixpkgs> { },
}:

{
  # Test PostgreSQL service
  postgresql = pkgs.nixosTest {
    name = "postgresql-test";

    nodes = {
      database = { config, pkgs, ... }: {
        imports = [ ../modules/roles/server-core.nix ];

        services.postgresql = {
          enable = true;
          initialScript = ''
            CREATE USER testuser WITH PASSWORD 'testpass';
            CREATE DATABASE testdb OWNER testuser;
          '';
        };

        networking.firewall.allowedTCPPorts = [ 5432 ];
      };
    };

    testScript = ''
      database.start()
      database.wait_for_unit("postgresql.service")

      # Test PostgreSQL is running
      database.succeed("systemctl is-active postgresql.service")

      # Test database connection
      database.succeed("psql -U testuser -d testdb -c 'SELECT 1' >&2")

      print("PostgreSQL test passed!")
    '';
  };

  # Test Jellyfin service
  jellyfin = pkgs.nixosTest {
    name = "jellyfin-test";

    nodes = {
      media = { config, pkgs, ... }: {
        imports = [ ../modules/roles/media-node.nix ];

        services.jellyfin = {
          enable = true;
          dataDir = "/var/lib/jellyfin";
        };

        networking.firewall.allowedTCPPorts = [ 8096 ];
      };
    };

    testScript = ''
      media.start()
      media.wait_for_unit("jellyfin.service")

      # Test Jellyfin is running
      media.succeed("systemctl is-active jellyfin.service")

      # Test web interface is accessible
      media.succeed("curl -f http://localhost:8096 >&2")

      print("Jellyfin test passed!")
    '';
  };

  # Test SSH service
  ssh = pkgs.nixosTest {
    name = "ssh-test";

    nodes = {
      server = { config, pkgs, ... }: {
        imports = [ ../modules/roles/common.nix ];

        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        users.users.testuser = {
          password = "testpass";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
          ];
        };

        networking.firewall.allowedTCPPorts = [ 22 ];
      };
    };

    testScript = ''
      server.start()
      server.wait_for_unit("sshd.service")

      # Test SSH is running
      server.succeed("systemctl is-active sshd.service")

      # Test SSH configuration
      server.succeed("sshd -T | grep -q 'passwordauthentication no'")
      server.succeed("sshd -T | grep -q 'permitrootlogin no'")

      print("SSH test passed!")
    '';
  };

  # Test Grafana service
  grafana = pkgs.nixosTest {
    name = "grafana-test";

    nodes = {
      monitoring = { config, pkgs, ... }: {
        imports = [ ../modules/features/grafana ];

        services.grafana = {
          enable = true;
          settings.server = {
            http_port = 3000;
          };
        };

        networking.firewall.allowedTCPPorts = [ 3000 ];
      };
    };

    testScript = ''
      monitoring.start()
      monitoring.wait_for_unit("grafana.service")

      # Test Grafana is running
      monitoring.succeed("systemctl is-active grafana.service")

      # Test web interface is accessible
      monitoring.succeed("curl -f http://localhost:3000/api/health >&2")

      print("Grafana test passed!")
    '';
  };
}
