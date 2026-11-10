# Dedicated, unprivileged deployment identity.
#
# Deployment is pull-based: the deploy user may run exactly one sudo command,
# `deploy-rebuild`, which rebuilds this host from a pinned revision of the
# repository flake. The deploy user cannot run arbitrary commands as root, has
# no interactive shell session (the authorized key is `restrict`ed), and is the
# only non-wheel identity allowed through sshd.
#
# Use `nix run .#deploy -- <host>` from a clean, pushed checkout to drive it.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.roles.security.deployUser;

  rebuildWrapper = pkgs.writeShellApplication {
    name = "deploy-rebuild";
    runtimeInputs = [
      pkgs.nixos-rebuild
      pkgs.git
    ];
    text = ''
      action="''${1:-}"
      rev="''${2:-}"

      case "$action" in
        switch) ;;
        *)
          echo "usage: deploy-rebuild switch <git-rev>" >&2
          exit 2
          ;;
      esac

      if [[ ! "$rev" =~ ^[0-9a-f]{40}$ ]]; then
        echo "deploy-rebuild: expected a full 40-character commit hash, got '$rev'" >&2
        exit 2
      fi

      if ! git ls-remote "${lib.escapeShellArg cfg.flakeRef}" | grep -E "^''${rev}[[:space:]]" >/dev/null; then
        echo "deploy-rebuild: revision is not reachable from ${lib.escapeShellArg cfg.flakeRef}" >&2
        exit 1
      fi

      exec nixos-rebuild "$action" \
        --flake "git+${cfg.flakeRef}?rev=''${rev}#${config.networking.hostName}"
    '';
  };
in
{
  options.roles.security.deployUser = {
    enable = lib.mkEnableOption "dedicated deployment user";

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Aljam/nixlab.git";
      description = ''
        Flake reference (without revision) the deployment user is permitted
        to rebuild from. The revision is supplied per deployment.
      '';
    };

    authorizedKeyFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets/deploy_authorized_key.pub;
      description = "Public key allowed to trigger deployments.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.deploy = { };

    users.users.deploy = {
      isSystemUser = true;
      group = "deploy";
      # A real shell is required for sshd to execute the forced-style command;
      # `restrict` on the key denies PTY allocation and all forwarding.
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "restrict ${lib.fileContents cfg.authorizedKeyFile}"
      ];
    };

    # sshd is otherwise wheel-only (modules/features/ssh.nix).
    services.openssh.settings.AllowGroups = [ "deploy" ];

    environment.systemPackages = [ rebuildWrapper ];

    security.sudo.extraRules = [
      {
        users = [ "deploy" ];
        commands = [
          {
            # Match the system-profile path, as resolved through sudo's secure_path.
            command = "/run/current-system/sw/bin/deploy-rebuild *";
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
