# Dedicated unprivileged account for remote Nix builds.
#
# Build clients connect as this user rather than an interactive
# administrative user. Add each build client's root public key below before
# deploying; otherwise remote builds will fail authentication.
{
  config,
  pkgs,
  ...
}:

{
  users.users.nix-builder = {
    isNormalUser = true;
    description = "Remote Nix builder";
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      # Replace with the public key used by each build client's root user.
      # "ssh-ed25519 AAAA... root@build-client"
    ];
  };

  nix.settings.trusted-users = [ "nix-builder" ];
}
