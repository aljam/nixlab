# Cross-cutting security policies evaluated for every host.
#
# These assertions turn the repository's security decisions into build-time
# checks. They are intentionally conservative: a policy should be added here
# only when violating it represents a real security or exposure regression.
{
  config,
  lib,
  ...
}:

let
  sopsSecrets = lib.attrValues config.sops.secrets;

  postgresAuth = config.services.postgresql.authentication or "";
in
{
  assertions = [
    # Preserve the service-scoped SOPS model. A missing `sopsFile` would
    # otherwise depend on a global default, which this repository intentionally
    # does not define.
    {
      assertion = lib.all (secret: secret.sopsFile != null) sopsSecrets;
      message = "Every sops secret must declare an explicit sopsFile.";
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
  ];
}
