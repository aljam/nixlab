# Service Isolation Test
# Verifies that backend services (vaultwarden, postgres, servarr) are only
# reachable via HAProxy and NOT directly accessible from external hosts.

{ nixosLib, pkgs, ... }:

let
  # Test network configuration
  gatewayIP = "192.168.1.1";
  backendIP = "192.168.1.10";
  externalIP = "192.168.1.100";
  haproxyIP = "192.168.1.254";  # pfSense HAProxy source IP

  # Backend node with all services
  backendNode = { name, ... }:
    nixosLib.evalConfig {
      modules = [
        ({ config, ... }: {
          networking.hostName = name;
          networking.useDHCP = false;
          networking.interfaces.ens1.ipv4.addresses = [
            { address = backendIP; prefixLength = 24; }
          ];
          networking.defaultGateway = gatewayIP;

          # Enable services being tested
          services.postgresql = {
            enable = true;
            listen_addresses = backendIP;
            port = 5432;
          };

          services.vaultwarden = {
            enable = true;
            config = {
              domain = "http://localhost:8200";
              signups_allowed = false;
            };
          };

          # Servarr stack (simplified for testing)
          systemd.services.radarr = {
            enable = true;
            description = "Radarr (test)";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.bash}/bin/bash -c 'sleep infinity'";
              User = "radarr";
              Group = "radarr";
            };
          };
          users.users.radarr = { isSystemUser = true; group = "radarr"; };
          users.groups.radarr = { };

          # Firewall: only allow HAProxy IP to reach backend ports
          networking.firewall = {
            enable = true;
            allowPing = false;
            extraInputRules = ''
              # Allow HAProxy to reach backend services
              ip saddr ${haproxyIP} tcp dport { 8200, 5432, 8080, 8081, 8082, 8083 } accept
              
              # Drop all other access to backend ports
              tcp dport { 8200, 5432, 8080, 8081, 8082, 8083 } drop
            '';
          };
        })
      ];
    };

  # External host (attacker/compromised machine)
  externalNode = { name, ... }:
    nixosLib.evalConfig {
      modules = [
        ({ config, ... }: {
          networking.hostName = name;
          networking.useDHCP = false;
          networking.interfaces.ens1.ipv4.addresses = [
            { address = externalIP; prefixLength = 24; }
          ];
          networking.defaultGateway = gatewayIP;
          networking.firewall.enable = false;
        })
      ];
    };

  # HAProxy node (legitimate proxy)
  haproxyNode = { name, ... }:
    nixosLib.evalConfig {
      modules = [
        ({ config, ... }: {
          networking.hostName = name;
          networking.useDHCP = false;
          networking.interfaces.ens1.ipv4.addresses = [
            { address = haproxyIP; prefixLength = 24; }
          ];
          networking.defaultGateway = gatewayIP;
          networking.firewall.enable = false;
        })
      ];
    };

in {
  name = "service-isolation";

  nodes = {
    backend = backendNode "backend";
    external = externalNode "external";
    haproxy = haproxyNode "haproxy";
  };

  testScript = { nodes, ... }: ''
    start_all()

    backend.wait_for_unit("multi-user.target")
    external.wait_for_unit("multi-user.target")
    haproxy.wait_for_unit("multi-user.target")

    # Wait for services to be ready
    backend.wait_for_open_port(5432)
    backend.wait_for_open_port(8200)

    print("\n=== Service Isolation Test ===")
    print("Backend IP: ${backendIP}")
    print("HAProxy IP: ${haproxyIP}")
    print("External IP: ${externalIP}")

    # Test 1: External host CANNOT reach Vaultwarden (8200)
    print("\n[Test 1] External host -> Vaultwarden:8200 (should FAIL)")
    external.wait_for_failing_unit(
        f"nc -z -w2 {backendIP} 8200"
    )
    print("✓ PASS: External host cannot reach Vaultwarden")

    # Test 2: External host CANNOT reach Postgres (5432)
    print("\n[Test 2] External host -> Postgres:5432 (should FAIL)")
    external.wait_for_failing_unit(
        f"nc -z -w2 {backendIP} 5432"
    )
    print("✓ PASS: External host cannot reach Postgres")

    # Test 3: External host CANNOT reach Servarr ports (8080-8083)
    print("\n[Test 3] External host -> Servarr:8080-8083 (should FAIL)")
    for port in [8080, 8081, 8082, 8083]:
        external.wait_for_failing_unit(
            f"nc -z -w2 {backendIP} {port}"
        )
    print("✓ PASS: External host cannot reach Servarr ports")

    # Test 4: HAProxy CAN reach Vaultwarden (8200)
    print("\n[Test 4] HAProxy -> Vaultwarden:8200 (should SUCCEED)")
    haproxy.wait_for_open_port(${backendIP}:8200)
    print("✓ PASS: HAProxy can reach Vaultwarden")

    # Test 5: HAProxy CAN reach Postgres (5432)
    print("\n[Test 5] HAProxy -> Postgres:5432 (should SUCCEED)")
    haproxy.wait_for_open_port(${backendIP}:5432)
    print("✓ PASS: HAProxy can reach Postgres")

    # Test 6: HAProxy CAN reach Servarr ports (8080-8083)
    print("\n[Test 6] HAProxy -> Servarr:8080-8083 (should SUCCEED)")
    for port in [8080, 8081, 8082, 8083]:
        haproxy.wait_for_open_port(f"{backendIP}:{port}")
    print("✓ PASS: HAProxy can reach Servarr ports")

    # Test 7: Verify firewall rules are in place
    print("\n[Test 7] Verify nftables rules on backend")
    backend.succeed("nft list ruleset | grep -q 'dport 8200 drop'")
    backend.succeed("nft list ruleset | grep -q 'dport 5432 drop'")
    print("✓ PASS: Firewall rules are correctly configured")

    print("\n=== All Service Isolation Tests PASSED ===")
  '';
}
