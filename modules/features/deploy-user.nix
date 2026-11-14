# Dedicated, unprivileged deployment identity.
#
# Deployment is pull-based: the deploy user may run exactly one sudo command,
# `deploy-rebuild`, which rebuilds this host from the current tip of the
# repository's main branch. The deploy user cannot run arbitrary commands as root,
# has no interactive shell session, and its SSH key is restricted to the
# deployment command.
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

  # The only ref hosts will deploy from. `nix run .#deploy` enforces the same
  # rule locally before it connects.
  deployRef = "refs/heads/main";

  rebuildWrapper = pkgs.writeShellApplication {
    name = "deploy-rebuild";
    runtimeInputs = [
      pkgs.nixos-rebuild
      pkgs.git
      pkgs.gnugrep
    ];
    text = ''
      action="''${1:-}"
      rev="''${2:-}"
      remote=${lib.escapeShellArg cfg.flakeRef}
      ref=${lib.escapeShellArg deployRef}

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

      # Ask only for the deployment branch. An unfiltered `git ls-remote` also
      # lists refs/pull/*/head, which anyone can create on a public repository
      # by opening a pull request.
      if ! advertised="$(git ls-remote "$remote" "$ref")"; then
        echo "deploy-rebuild: cannot read $ref from $remote" >&2
        exit 1
      fi

      # ls-remote patterns match trailing path components, so compare the
      # whole "<rev><TAB><ref>" line instead of trusting the filter.
      if ! grep --quiet --fixed-strings --line-regexp -- "$rev"$'\t'"$ref" <<<"$advertised"; then
        echo "deploy-rebuild: $rev is not the tip of $ref on $remote" >&2
        exit 1
      fi

      exec nixos-rebuild "$action" \
        --flake "git+$remote?rev=$rev#${config.networking.hostName}"
    '';
  };

  # SSH can invoke only this wrapper. It validates the client-supplied command
  # before delegating to the sudo-limited rebuild wrapper.
  sshCommandWrapper = pkgs.writeShellApplication {
    name = "deploy-rebuild-ssh";
    runtimeInputs = [
      pkgs.gnugrep
    ];
    text = ''
      rev=""
      if [[ "''${SSH_ORIGINAL_COMMAND:-}" =~ ^deploy-rebuild\ switch\ ([0-9a-f]{40})$ ]]; then
        rev="''${BASH_REMATCH[1]}"
      else
        echo "deploy-rebuild-ssh: only 'deploy-rebuild switch <git-rev>' is permitted" >&2
        exit 2
      fi

      exec /run/wrappers/bin/sudo -n \
        /run/current-system/sw/bin/deploy-rebuild switch \
        "$rev"
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
        Git remote (without revision) the deployment user is permitted to
        rebuild from. The revision is supplied per deployment and must be
        the current tip of the remote's main branch.
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
      # A real shell is required for sshd to execute the forced command;
      # `restrict` denies PTY allocation and forwarding, while `command`
      # permits only the deployment wrapper.
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "command=\"${lib.getExe sshCommandWrapper}\",restrict ${lib.fileContents cfg.authorizedKeyFile}"
      ];
    };

    # sshd is otherwise wheel-only (modules/features/ssh.nix).
    services.openssh.settings.AllowGroups = [ "deploy" ];

    environment.systemPackages = [
      rebuildWrapper
      sshCommandWrapper
    ];

    security.sudo.extraRules = [
      {
        users = [ "deploy" ];
        commands = [
          {
            # Match the system-profile path, as resolved through sudo's secure_path.
            # Restrict the wildcard to the sole supported deployment action.
            command = "/run/current-system/sw/bin/deploy-rebuild switch *";
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
