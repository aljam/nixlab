{ config, lib, ... }:

let
  backendPorts = config.networking.proxyBackendPorts;

  nodeExporter = config.services.prometheus.exporters.node;
  prometheusIP = config.networking.fleet.${config.networking.monitoringServer}.ip;

  haproxyRule = lib.concatMapStrings (
    port:
    ''
      ip saddr ${config.networking.fleet.proxy.ip} tcp dport ${toString port} accept comment "HAProxy backend"
    ''
  ) backendPorts;

  prometheusRule = lib.optionalString (nodeExporter.enable && prometheusIP != null) ''
    ip saddr ${prometheusIP} tcp dport ${toString nodeExporter.port} accept comment "Prometheus node exporter scrape"
  '';

  # Sensitive or internal-only services that must not be exposed through the
  # HAProxy backend allowlist.
  internalServicePorts = {
    pgAdmin = 5050;
    prometheus = 9090;
    blackboxExporter = 9115;
    alertmanager = 9093;
    postgresql = config.services.postgresql.settings.port or 5432;
  };

  forbiddenProxyPorts = lib.attrValues internalServicePorts;
  forbiddenExposedPorts = lib.intersectLists forbiddenProxyPorts backendPorts;
  duplicateProxyPorts = lib.lists.subtractLists (lib.unique backendPorts) backendPorts;

  serviceBindAddress = config.networking.servicesBindAddress or null;
in
{
  networking.firewall.extraInputRules = lib.concatStrings [
    haproxyRule
    prometheusRule
  ];

  assertions = [
    # Services using the shared bind address must never listen on every
    # interface; use loopback or an explicit fleet service address. An unset
    # address means this host does not use the shared service-bind policy.
    {
      assertion =
        serviceBindAddress == null
        || (
          serviceBindAddress != "0.0.0.0" && serviceBindAddress != "::"
        );
      message = "servicesBindAddress must not bind services to every interface.";
    }

    # Duplicate backend ports make the exposure allowlist misleading and are
    # usually a configuration mistake.
    {
      assertion = duplicateProxyPorts == [ ];
      message = "HAProxy backend ports must not contain duplicates.";
    }

    # Prevent sensitive or internal-only services from being exposed through
    # the HAProxy backend allowlist.
    {
      assertion = forbiddenExposedPorts == [ ];
      message =
        "Forbidden service ports must not be exposed through the HAProxy backend allowlist: "
        + lib.concatStringsSep ", " (map (p: toString p) forbiddenExposedPorts);
    }
  ];
}
