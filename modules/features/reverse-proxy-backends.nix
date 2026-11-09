{ config, lib, ... }:

let
  backendPorts = config.networking.proxyBackendPorts;
  proxyIP = config.networking.fleet.proxy.ip;
  monitoringServer = config.networking.monitoringServer;
  prometheusIP =
    if monitoringServer == null then null else config.networking.fleet.${monitoringServer}.ip;
  nodeExporter = config.services.prometheus.exporters.node;

  # The HAProxy gateway is the only client allowed to reach service backends.
  haproxyRule = lib.optionalString (backendPorts != [ ]) ''
    ip saddr ${proxyIP} tcp dport { ${
      lib.concatMapStringsSep ", " toString backendPorts
    } } accept comment "HAProxy backend access"
  '';

  # Only the Prometheus server may scrape node_exporter, and only on hosts that
  # actually run it.
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
in
{
  networking.firewall.extraInputRules = lib.concatStrings [
    haproxyRule
    prometheusRule
  ];

  assertions = [
    # Services using the shared bind address must never listen on every
    # interface; use loopback or an explicit fleet service address.
    {
      assertion =
        config.networking.servicesBindAddress != "0.0.0.0" && config.networking.servicesBindAddress != "::";
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
