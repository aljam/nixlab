{
  lib,
  ...
}:
let
  subnets = {
    lan = "192.168.1";
    nas = "192.168.2";
    management = "127.0.0.0/8";
  };

  domains = {
    primary = "derezzed.info";
    fuwa = "fuwa.space";
    cybal = "cybal.org";
    netrunner = "netrunner.dev";
    glow_net = "glowrunner.network";
    glow_dev = "glowrunner.dev";
    glow_xyz = "glowrunner.xyz";
  };

  fleet = {
    navi = { };
    oryx = { };
    r820 = {
      ip = "${subnets.lan}.4";
    };
    r730 = {
      ip = "${subnets.lan}.3";
      zpool = "r730pool";
    };
    r730xd = {
      ip = "${subnets.lan}.2";
      zpool = "mediapool";
    };
    proxy = {
      ip = "${subnets.lan}.1";
    };
    nas = {
      ip = "${subnets.nas}.10";
    };
  };

  fleetIps = lib.filter (ip: ip != null) (
    lib.mapAttrsToList (_: host: host.ip or null) fleet
  );

  duplicateIps = lib.subtractLists (lib.unique fleetIps) fleetIps;

  allowedIpPrefixes = [
    "${subnets.lan}."
    "${subnets.nas}."
  ];

  invalidIps = lib.filter (
    ip: !lib.any (prefix: lib.hasPrefix prefix ip) allowedIpPrefixes
  ) fleetIps;

  # Ports that must remain internal-only and must never be added to the
  # HAProxy backend allowlist.
  internalOnlyPorts = [
    5432 # PostgreSQL
    9090 # Prometheus
    9115 # Prometheus Blackbox exporter
    3100 # Loki
  ];

  exposedInternalPorts = lib.intersectLists internalOnlyPorts config.networking.proxyBackendPorts;
in
{
  options.networking = {
    fleet = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            ip = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Static service address for the host, if any.";
            };

            zpool = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Primary ZFS pool for the host, if any.";
            };
          };
        }
      );
      description = "Static metadata for hosts in the fleet, such as service IPs and ZFS pools.";
    };

    subnets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Named network prefixes used by the fleet configuration.";
    };

    # Named myDomain to avoid conflicting with NixOS's networking.domain.
    myDomain = lib.mkOption {
      type = lib.types.str;
      description = "Primary DNS domain used by hosts in the fleet.";
    };

    domains = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Named DNS domains available to service configuration.";
    };

    monitoringServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "r730xd";
      description = "Fleet host running the Prometheus server.";
    };

    proxyBackendPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "TCP ports reachable from the pfSense HAProxy backend. Feature modules append their own ports.";
    };
  };

  config.networking = {
    inherit fleet subnets domains;
    myDomain = domains.primary;
  };

  config.assertions = [
    {
      assertion = duplicateIps == [ ];
      message = "Fleet host IPs must be unique. Duplicates: ${lib.concatStringsSep ", " duplicateIps}";
    }
    {
      assertion = invalidIps == [ ];
      message =
        "Fleet host IPs must belong to an allowed subnet (${lib.concatStringsSep ", " allowedIpPrefixes}). Invalid: ${lib.concatStringsSep ", " invalidIps}";
    }
    {
      assertion = exposedInternalPorts == [ ];
      message =
        "Internal-only services must not be exposed through the HAProxy backend allowlist. Exposed ports: ${lib.concatMapStringsSep ", " toString exposedInternalPorts}";
    }
  ];
}
