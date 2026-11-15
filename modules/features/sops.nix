{ lib, config, ... }:

let
  # Declare every secret consumed by a module through this helper.
  #
  # The helper makes the secret name, SOPS file, owning user and group, and
  # user-activation requirement explicit. It also enforces owner-only mode
  # 0400.
  #
  # Service-specific SOPS options, such as `restartUnits`, may be supplied as
  # additional arguments. The helper preserves them, but callers cannot
  # override the mandatory owner-only mode.
  #
  # The helper does not encrypt, rotate, deploy, or validate secret contents.
  # Root-owned secrets require an explicit entry in
  # roles.security.sopsAllowedRootSecrets.
  mkSecret =
    {
      name,
      sopsFile,
      owner,
      group,
      neededForUsers ? false,
      ...
    }@args:
    args
    // {
      inherit
        name
        sopsFile
        owner
        group
        neededForUsers
        ;
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

  # Normalize each secret file to its repository-relative location beneath
  # `secrets/`. Secret files are intentionally flat, so the basename is
  # sufficient and avoids depending on the absolute checkout path.
  secretRelativePaths = map (secret: "secrets/${builtins.baseNameOf secret.sopsFile}") sopsSecrets;

  unapprovedSecretFiles = lib.filter (
    relativePath: !(lib.hasAttr relativePath config.roles.security.sopsApprovedFiles)
  ) secretRelativePaths;

  unauthorizedHostSecretFiles = lib.filter (
    relativePath:
    let
      approvedHosts = config.roles.security.sopsApprovedFiles.${relativePath} or [ ];
    in
    !(lib.elem config.networking.hostName approvedHosts)
  ) secretRelativePaths;
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

  options.roles.security.sopsApprovedFiles = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = { };
    description = ''
      Maps SOPS secret files, identified as `secrets/<file>.yaml`, to the
      NixOS hosts permitted to decrypt them. The operator identity is not a
      host and must not appear in these lists.
    '';
  };

  config._module.args.mkSecret = mkSecret;

  config.roles.security.sopsApprovedFiles = {
    "secrets/common.yaml" = [
      "navi"
      "oryx"
      "r730"
      "r730xd"
      "r820"
    ];

    "secrets/nas.yaml" = [
      "navi"
      "oryx"
    ];

    "secrets/database.yaml" = [
      "r820"
    ];

    "secrets/matrix.yaml" = [
      "r730xd"
      "r820"
    ];

    "secrets/vaultwarden.yaml" = [
      "r730xd"
      "r820"
    ];

    "secrets/monitoring.yaml" = [
      "r730"
      "r730xd"
      "r820"
    ];

    "secrets/media.yaml" = [
      "r730xd"
    ];

    "secrets/mail.yaml" = [
      "r820"
    ];

    "secrets/acme.yaml" = [
      "r820"
    ];

    "secrets/radio.yaml" = [
      "r730xd"
    ];

    "secrets/backups.yaml" = [
      "r730xd"
      "r820"
    ];

    "secrets/peertube.yaml" = [
      "r730xd"
    ];
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

    # Keep encrypted secrets within the dedicated repository secrets tree.
    {
      assertion = lib.all (
        secret:
        lib.hasInfix "/secrets/" (toString secret.sopsFile)
        && lib.hasSuffix ".yaml" (toString secret.sopsFile)
      ) sopsSecrets;
      message = "Every SOPS secret file must reside beneath secrets/ and use a YAML file.";
    }

    # Every secret file must be explicitly approved in the repository policy.
    {
      assertion = unapprovedSecretFiles == [ ];
      message =
        "SOPS secret files must be listed in roles.security.sopsApprovedFiles: "
        + lib.concatStringsSep ", " unapprovedSecretFiles;
    }

    # Prevent a host from decrypting a secret file intended for another trust
    # boundary.
    {
      assertion = unauthorizedHostSecretFiles == [ ];
      message =
        "This host is not approved to decrypt one or more SOPS secret files: "
        + lib.concatStringsSep ", " unauthorizedHostSecretFiles;
    }
  ];
}
