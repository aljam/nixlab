{ lib, config, ... }:

let
  mkSecret = {
    name,
    sopsFile,
    owner,
    group,
    neededForUsers ? false,
    ...
  }: {
    inherit name sopsFile owner group neededForUsers;
    mode = "0400";
  };

  sopsSecrets = lib.attrValues config.sops.secrets;

  rootOwnedSecrets = lib.filter (secret: secret.owner == "root") sopsSecrets;

  unauthorizedRootOwnedSecrets = lib.filter (
    secret: !lib.elem secret.name config.roles.security.sopsAllowedRootSecrets
  ) rootOwnedSecrets;

  unauthorizedSecretNames = map (secret: secret.name) unauthorizedRootOwnedSecrets;

  undeclaredSecretOwners = lib.filter (
    secret: secret.owner != "root" && !lib.hasAttr secret.owner config.users.users
  ) sopsSecrets;

  undeclaredSecretGroups = lib.filter (
    secret: !lib.hasAttr secret.group config.users.groups
  ) sopsSecrets;
in
{
  options.roles.security.sopsAllowedRootSecrets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
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

    # Make the effective group identity explicit. This prevents a secret from
    # inheriting an unintended group or relying on an implicit default.
    {
      assertion = lib.all (secret: secret.group != null) sopsSecrets;
      message = "Every sops secret must declare an explicit group.";
    }

    # Make permissions explicit and restrict every secret to its owning
    # service identity.
    {
      assertion = lib.all (secret: secret.mode == "0400") sopsSecrets;
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

    # Prevent typos or accidental references to undeclared service identities.
    {
      assertion = undeclaredSecretOwners == [ ];
      message =
        "SOPS secret owners must be declared system users. Undeclared owners: "
        + lib.concatStringsSep ", " (map (secret: secret.owner) undeclaredSecretOwners);
    }

    # Prevent typos or accidental references to undeclared groups.
    {
      assertion = undeclaredSecretGroups == [ ];
      message =
        "SOPS secret owners must be declared system groups. Undeclared groups: "
        + lib.concatStringsSep ", " (map (secret: secret.group) undeclaredSecretGroups);
    }
  ];
}
