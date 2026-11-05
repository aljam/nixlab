{
  lib,
  config,
  ...
}:
{
  options.roles.security.deployUser.enable = lib.mkEnableOption "dedicated unprivileged deployment user";

  config = lib.mkIf config.roles.security.deployUser.enable {
    users.users.deploy = {
      isSystemUser = true;
      group = "deploy";
      home = "/var/lib/deploy";
      createHome = true;
      shell = "/run/current-system/sw/bin/nologin";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIANdQitHwS6CtfYfgBzFJBjAyCow9qiPHlkybc5GTBwn nixlab-deploy"
      ];
    };

    users.groups.deploy = { };

    security.sudo.extraRules = [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    services.openssh.settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
