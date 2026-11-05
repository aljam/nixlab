{ lib, config, ... }:

let
  sopsSecrets = lib.attrValues config.sops.secrets;

  grafanaExposed = lib.elem 3000 config.networking.proxyBackendPorts;
  grafanaAnonymous = config.services.grafana.settings.auth.anonymous.enabled or false;
  grafanaSignup = config.services.grafana.settings.users.allow_sign_up or false;

  postgresAuth = config.services.postgresql.authentication or "";
  postgresPort = config.services.postgresql.settings.port or 5432;
  proxyBackendPorts = config.networking.proxyBackendPorts;
  duplicateProxyPorts = lib.lists.subtractLists
    (lib.unique proxyBackendPorts)
    proxyBackendPorts;

  # Sensitive or internal-only services that must not be exposed
  # through the HAProxy backend allowlist.
  forbiddenProxyPorts = [
    5050 # pgAdmin
    9090 # Prometheus
    9115 # Prometheus Blackbox exporter
    9093 # Alertmanager
  ];

  forbiddenExposedPorts = lib.intersectLists
    forbiddenProxyPorts
    proxyBackendPorts;

  # Remote PostgreSQL clients must explicitly negotiate TLS. Loopback rules
  # are exempt because their traffic does not traverse a network interface.
  plaintextRemotePostgresRules = lib.filter
    (line:
      let
        trimmed = lib.strings.trim line;
      in
      lib.strings.hasPrefix "host " trimmed
      && !(lib.strings.hasInfix "127.0.0.1/32" trimmed)
      && !(lib.strings.hasInfix "::1/128" trimmed)
    )
    (lib.strings.splitString "\n" postgresAuth);

  gamingEnabled =
    (config.programs.steam.enable or false)
    || (config.programs.gamescope.enable or false);

  rootOwnedSecrets = lib.filter
    (secret: secret.owner == "root")
    sopsSecrets;

  unauthorizedRootOwnedSecrets = lib.filter
    (secret: !lib.elem secret.name config.roles.security.sopsAllowedRootSecrets)
    rootOwnedSecrets;

  unauthorizedSecretNames = map (secret: secret.name) unauthorizedRootOwnedSecrets;
in
{
  options.roles.server.enable = lib.mkEnableOption "server role policies";

  options.roles.security.sopsAllowedRootSecrets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "nas-credentials"
      "smtp_relay_password"
      "mail_password_aljam"
      "livekit-jwt-env"
      "icecast-admin-password"
      "icecast-relay-password"
      "icecast-source-password"
    ];
    description = ''
      Names of SOPS secrets that are explicitly allowed to be owned by root.
      This is intended for system-level credentials such as mount credentials,
      mail relay configuration, and services that do not yet have a
      dedicated unprivileged identity.
    '';
  };

  config.assertions = [
    # Preserve the service-scoped SOPS model. A missing `sopsFile` would
    # otherwise depend on a global default, which this repository intentionally
    # does not define.
    {
      assertion = lib.all (secret: secret.sopsFile != null) sopsSecrets;
      message = "Every sops secret must declare an explicit sopsFile.";
    }

    # Make the effective identity of every decrypted secret explicit.
    {
      assertion = lib.all (secret: secret.owner != null) sopsSecrets;
      message = "Every sops secret must declare an explicit owner.";
    }

    # Make permissions explicit and restrict every secret to its owning
    # service identity.
    {
      assertion = lib.all (secret: secret.mode != null) sopsSecrets;
      message = "Every sops secret must declare an explicit mode.";
    }

    {
      assertion = lib.all
        (secret: secret.mode == "0400")
        sopsSecrets;
      message = "SOPS secrets must use owner-only mode 0400.";
    }

    # Root ownership is sometimes necessary for system-level credentials,
    # but it must be explicit and auditable.
    {
      assertion = unauthorizedRootOwnedSecrets == [ ];
      message = ''
        SOPS secrets owned by root must be listed in
        roles.security.sopsAllowedRootSecrets. Unauthorized secrets:
        ${lib.concatStringsSep ", " unauthorizedSecretNames}
      '';
    }

    # Grafana is the internet-facing monitoring dashboard. It must require
    # authentication and must not permit self-registration.
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
      message = "Forbidden service ports must not be exposed through the HAProxy backend allowlist: "
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
        config.networking.servicesBindAddress != "0.0.0.0"
        && config.networking.servicesBindAddress != "::";
      message = "servicesBindAddress must not bind services to every interface.";
    }

    # Duplicate backend ports make the exposure allowlist misleading and are
    # usually a configuration mistake.
    {
      assertion = duplicateProxyPorts == [ ];
      message = "HAProxy backend ports must not contain duplicates.";
    }

    # Autobrr should use the host's service address rather than every interface.
    {
      assertion =
        !(config.services.autobrr.enable or false)
        || config.services.autobrr.settings.host != "0.0.0.0";
      message = "Autobrr must bind to the host service address, not all interfaces.";
    }

    # Recyclarr connects to local Radarr and Sonarr instances.
    {
      assertion =
        !(config.modules.features.recyclarr.enable or false)
        || config.servarr.enable;
      message = "modules.features.recyclarr requires servarr.enable because it connects to local Radarr and Sonarr.";
    }

    # Gaming software opens LAN-facing ports and is intended only for desktop
    # hosts. Prevent accidental inclusion in server roles.
    {
      assertion =
        !(config.roles.server.enable or false)
        || !gamingEnabled;
      message = "Steam, GameScope, and gaming firewall rules must not be enabled on server hosts.";
    }

    # If sudo is enabled, administrative commands must require a password.
    {
      assertion =
        !(config.security.sudo.enable or false)
        || config.security.sudo.wheelNeedsPassword;
      message = "sudo must require a password when enabled.";
    }

    # SSH must remain key-only; password authentication is disabled centrally.
    {
      assertion =
        !(config.services.openssh.enable or false)
        || config.services.openssh.settings.PasswordAuthentication == false;
      message = "SSH password authentication must remain disabled.";
    }
  ];
}
