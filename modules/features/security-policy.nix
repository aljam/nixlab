{ lib, config, ... }:

let
  sopsSecrets = lib.attrValues config.sops.secrets;

  allowedSecretModes = [
    "0400"
    "0640"
  ];

  groupReadableSecrets = [
    "grafana-admin-password"
    "grafana-secret-key"
    "vaultwarden-admin-token"
  ];

  postgresAuth = config.services.postgresql.authentication or "";
  postgresPort = config.services.postgresql.settings.port or 5432;
  proxyBackendPorts = config.networking.proxyBackendPorts;
  duplicateProxyPorts = lib.lists.subtractLists
    (lib.unique proxyBackendPorts)
    proxyBackendPorts;

  gamingEnabled =
    (config.programs.steam.enable or false)
    || (config.programs.gamescope.enable or false);
in
{
  options.roles.server.enable = lib.mkEnableOption "server role policies";

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

    # Make permissions explicit and restrict group-readable secrets to
    # documented service exceptions.
    {
      assertion = lib.all (secret: secret.mode != null) sopsSecrets;
      message = "Every sops secret must declare an explicit mode.";
    }

    {
      assertion = lib.all
        (secret:
          lib.elem secret.mode allowedSecretModes
          && (secret.mode == "0400" || lib.elem secret.name groupReadableSecrets))
        sopsSecrets;
      message = "SOPS secrets must use mode 0400; 0640 is allowed only for documented Grafana and Vaultwarden exceptions.";
    }

    # Prevent regression to broad PostgreSQL authentication rules.
    {
      assertion = !(lib.hasInfix "host all all" postgresAuth);
      message = "PostgreSQL authentication must not contain broad host/all/all rules.";
    }

    # pgAdmin is a powerful administrative interface and must remain
    # loopback-only unless a separate, explicitly reviewed exposure path exists.
    {
      assertion = !(lib.elem 5050 config.networking.proxyBackendPorts);
      message = "pgAdmin must not be exposed through the HAProxy backend allowlist.";
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
