{ lib, config, ... }:

{
  options.roles.security.deployUser.enable = lib.mkEnableOption "dedicated deployment user";

  config = lib.mkIf config.roles.security.deployUser.enable {
    users.groups.deploy = { };

    users.users.deploy = {
      isSystemUser = true;
      group = "deploy";
      shell = "/run/current-system/sw/bin/nologin";
      openssh.authorizedKeys.keyFiles = [
        "/run/secrets/deploy_authorized_key"
      ];
    };

    security.sudo.extraRules = [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    assertions = [
      {
        assertion = config.services.openssh.enable;
        message = "The deploy user requires OpenSSH.";
      }
      {
        assertion = config.services.openssh.settings.PasswordAuthentication == false;
        message = "The deploy user must use key-only SSH authentication.";
      }
    ];
  };
}
