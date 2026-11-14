# Cross-cutting security policy.
#
# This module enforces repository-wide invariants that apply across hosts,
# features, or deployment paths. It is intentionally not a dumping ground for
# every service-specific security check.
#
# Put a policy here when it:
#
# - Applies to more than one feature or host role.
# - Enforces a repository-wide invariant, such as SOPS secret ownership,
#   reverse-proxy exposure, shared service bind addresses, or sudo policy.
# - Prevents an unsafe configuration combination across features, such as
#   enabling gaming software on a server role.
#
# Put a policy in the owning feature module when it is intrinsic to that
# service. For example:
#
# - Grafana owns its authentication and self-registration requirements.
# - PostgreSQL owns its remote-access, TLS, and HAProxy exposure rules.
# - Autobrr owns its bind-address requirement.
# - SSH owns its authentication and forwarding policy.
# - SOPS owns secret file, owner, mode, and root-ownership assertions.
#
# A feature module may retain a narrower duplicate of a cross-cutting rule
# when its service-specific error message is materially clearer. Do not
# duplicate a cross-cutting assertion otherwise.
#
# Keep assertions narrowly scoped and actionable. Prefer a message that
# identifies the violating setting and states the required correction.

{ lib, config, ... }:

let
  proxyBackendPorts = config.networking.proxyBackendPorts;
  duplicateProxyPorts = lib.unique (
    lib.filter (port: lib.count (other: other == port) proxyBackendPorts > 1) proxyBackendPorts
  );

  # Internal-only service ports are centrally defined by
  # networking-options.nix. PostgreSQL is included there as well, but its
  # dedicated assertion provides a clearer, service-specific error.
  forbiddenProxyPorts = config.networking.internalOnlyPorts;

  forbiddenExposedPorts = lib.intersectLists forbiddenProxyPorts proxyBackendPorts;

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

    # Prevent sensitive or internal-only services from being exposed
    # through the HAProxy backend allowlist. The authoritative list is
    # maintained in networking-options.nix.
    {
      assertion = forbiddenExposedPorts == [ ];
      message =
        "Forbidden service ports must not be exposed through the HAProxy backend allowlist: "
        + lib.concatStringsSep ", " (map (p: toString p) forbiddenExposedPorts);
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
