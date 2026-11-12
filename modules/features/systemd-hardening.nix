# Apply a conservative systemd sandbox baseline to selected long-running
# services. Service modules retain responsibility for service-specific
# filesystem access, identities, and compatibility exceptions.
{ lib, config, ... }:
{
  options.roles.security.systemdHardenedServices = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Systemd services that should receive the repository's conservative
      sandboxing baseline. Service-specific options may still override these
      defaults when required.
    '';
  };

  config = {
    assertions = [
      {
        assertion = lib.all (
          name: lib.hasAttr name config.systemd.services
        ) config.roles.security.systemdHardenedServices;
        message =
          let
            unknown = lib.filter (
              name: !lib.hasAttr name config.systemd.services
            ) config.roles.security.systemdHardenedServices;
          in
          "systemdHardenedServices contains services that do not exist: ${lib.concatStringsSep ", " unknown}";
      }
    ];

    systemd.services = lib.listToAttrs (
      map (
        name:
        lib.nameValuePair name {
          serviceConfig = {
            NoNewPrivileges = lib.mkDefault true;
            PrivateTmp = lib.mkDefault true;
            ProtectHome = lib.mkDefault true;
            ProtectSystem = lib.mkDefault "strict";
            ProtectKernelTunables = lib.mkDefault true;
            ProtectKernelModules = lib.mkDefault true;
            ProtectControlGroups = lib.mkDefault true;
            RestrictSUIDSGID = lib.mkDefault true;
            LockPersonality = lib.mkDefault true;
          };
        }
      ) config.roles.security.systemdHardenedServices
    );
  };
}
