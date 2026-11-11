{ lib, config, ... }:

let
  grafanaPort = config.services.grafana.settings.server.http_port or 3000;
  grafanaExposed = lib.elem grafanaPort config.networking.proxyBackendPorts;
  # Grafana's section name is the single attribute "auth.anonymous", not the
  # nested path auth.anonymous.
  grafanaAnonymous = config.services.grafana.settings."auth.anonymous".enabled or false;
  grafanaSignup = config.services.grafana.settings.users.allow_sign_up or false;

  postgresAuth = config.services.postgresql.authentication or "";
  postgresPort = config.services.postgresql.settings.port or 5432;
  proxyBackendPorts = config.networking.proxyBackendPorts;
  duplicateProxyPorts = lib.unique (
    lib.filter (port: lib.count (other: other == port) proxyBackendPorts > 1) proxyBackendPorts
  );

  # Sensitive or internal-only services that must not be exposed
  # through the HAProxy backend allowlist.
  internalServicePorts = {
    pgAdmin = 5050;
    prometheus = 9090;
    blackboxExporter = 9115;
    alertmanager = 9093;
  };

  forbiddenProxyPorts = lib.attrValues internalServicePorts;

  forbiddenExposedPorts = lib.intersectLists forbiddenProxyPorts proxyBackendPorts;

  # Remote PostgreSQL clients must explicitly negotiate TLS. Loopback rules
  # are exempt because their traffic does not traverse a network interface.
  plaintextRemotePostgresRules = lib.filter (
    line:
    let
      trimmed = lib.strings.trim line;
    in
    lib.strings.hasPrefix "host " trimmed
    && !(lib.strings.hasInfix "127.0.0.1/32" trimmed)
    && !(lib.strings.hasInfix "::1/128" trimmed)
  ) (lib.strings.splitString "\n" postgresAuth);

  gamingEnabled =
    (config.programs.steam.enable or false) || (config.programs.gamescope.enable or false);

  sopsSecrets = lib.attrValues config.sops.secrets;

  # Map a secret to the service identity that is intended to consume it.
  # A mapping is checked only when that secret is declared on the evaluated
  # host, allowing host-specific secret sets to remain explicit.
  expectedOwners = config.roles.security.sopsExpectedOwners;

  mismatchedSecretOwners = lib.filter (
    secret:
    let
      expectedOwner = expectedOwners.${secret.name} or null;
    in
    expectedOwner != null && secret.owner != expectedOwner
  ) sopsSecrets;

  mismatchedSecretNames = map (secret: secret.name) mismatchedSecretOwners;
in
{
  options.roles.server.enable = lib.mkEnableOption "server role policies";

  options.roles.security.sopsExpectedOwners = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = ''
      Maps SOPS secret names to the service identity expected to own and
      consume them. A mapping is enforced only when the named secret is
      declared on the evaluated host.
    '';
  };

  config.assertions = [
    # The SOPS file, owner, mode and root-ownership assertions are owned by
    # modules/features/sops.nix.

    # Ensure that a mapped secret is owned by the service intended to
    # consume it. This prevents accidental credential sharing across
    # service identities.
    {
      assertion = mismatchedSecretOwners == [ ];
      message = ''
        SOPS secrets must be owned by their expected consuming service.
        Mismatched secrets:
        ${lib.concatStringsSep ", " mismatchedSecretNames}
      '';
    }

    # Grafana is the internet-facing monitoring dashboard. When exposed
    # through the HAProxy backend allowlist, it must require authentication
    # and must not permit self-registration.
    {
      assertion = !grafanaExposed || !grafanaAnonymous;
      message = "Grafana must disable anonymous access when exposed through the HAProxy backend allowlist.";
    }

    {
      assertion = !grafanaExposed || !grafanaSignup;
      message = "Grafana must disable self-registration when exposed through the HAProxy backend allowlist.";
    }

    # Prevent regression to broad PostgreSQL authentication rules.
    {
      assertion = !(lib.hasInfix "host all all" postgresAuth);
      message = "PostgreSQL authentication must not contain broad host/all/all rules.";
    }

    # Remote PostgreSQL authentication must explicitly require TLS.
    {
      assertion = plaintextRemotePostgresRules == [ ];
      message = "PostgreSQL authentication must use hostssl for every non-loopback client rule.";
    }

    # Prevent sensitive or internal-only services from being exposed
    # through the HAProxy backend allowlist.
    {
      assertion = forbiddenExposedPorts == [ ];
      message =
        "Forbidden service ports must not be exposed through the HAProxy backend allowlist: "
        + lib.concatStringsSep ", " (map (p: toString p) forbiddenExposedPorts);
    }

    # PostgreSQL is a sensitive backend service and must not be exposed
    # through the HAProxy backend allowlist.
    {
      assertion = !(lib.elem postgresPort proxyBackendPorts);
      message = "PostgreSQL must not be exposed through the HAProxy backend allowlist.";
    }

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
      message =
        "HAProxy backend ports must not contain duplicates: "
        + lib.concatMapStringsSep ", " toString duplicateProxyPorts;
    }

    # Autobrr should use the host's service address rather than every interface.
    {
      assertion =
        !(config.services.autobrr.enable or false) || config.services.autobrr.settings.host != "0.0.0.0";
      message = "Autobrr must bind to the host service address, not all interfaces.";
    }

    # Recyclarr connects to local Radarr and Sonarr instances.
    {
      assertion = !(config.modules.features.recyclarr.enable or false) || config.servarr.enable;
      message = "modules.features.recyclarr requires servarr.enable because it connects to local Radarr and Sonarr instances.";
    }

    # Gaming software opens LAN-facing ports and is intended only for desktop
    # hosts. Prevent accidental inclusion in server roles.
    {
      assertion = !(config.roles.server.enable or false) || !gamingEnabled;
      message = "Steam, GameScope, and gaming firewall rules must not be enabled on server hosts.";
    }

    # If sudo is enabled, administrative commands must require a password.
    {
      assertion = !(config.security.sudo.enable or false) || config.security.sudo.wheelNeedsPassword;
      message = "sudo must require a password when enabled.";
    }

    # SSH policy, including key-only authentication, is owned by
    # modules/features/ssh.nix.
  ];

  config.roles.security.sopsExpectedOwners = {
    "grafana-admin-password" = "grafana";
    "grafana-secret-key" = "grafana";
    "peertube-secrets" = "peertube";
    "vaultwarden-admin-token" = "vaultwarden";
    "nfty-url" = "alertmanager";
    "pfsense-root-ca-matrix" = "matrix-synapse";
    "radarr_api_key" = "recyclarr";
  };
}
