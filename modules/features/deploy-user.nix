{ lib, config, pkgs, ... }:

let
  cfg = config.roles.security.deployUser;
  rebuildWrapper = pkgs.writeShellApplication {
    name = "deploy-rebuild";
    runtimeInputs = [ pkgs.nixos-rebuild ];
    text = ''
      set -euo pipefail

      case "''${1:-}" in
        switch|test|boot|dry-build) ;;
        *)
          echo "usage: deploy-rebuild {switch|test|boot|dry-build}" >&2
          exit 2
          ;;
      esac

      exec nixos-rebuild "$1" --flake ${lib.escapeShellArg cfg.flakePath}
    '';
  };
in
{
  options.roles.security.deployUser = {
    enable = lib.mkEnableOption "dedicated deployment user";

    flakePath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixlab";
      description = ''
        Flake path the deployment user is permitted to rebuild.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.deploy = { };

    users.users.deploy = {
      isSystemUser = true;
      group = "deploy";
      shell = "/run/current-system/sw/bin/nologin";
      openssh.authorizedKeys.keys = [
        (builtins.readFile ../../secrets/deploy_authorized_key.pub)
      ];
    };

    environment.systemPackages = [ rebuildWrapper ];

    security.sudo.extraRules = [
      {
        users = [ "deploy" ];
        commands = [
          {
            command = lib.getExe rebuildWrapper;
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
