{ config, pkgs, ... }:

{
  users.users.aljam = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHzrMiro1XD8krk5Kb4EWQ+rGjmgKXha/OuOmUZcopRL aljam@navi"
    ];
    hashedPasswordFile = config.sops.secrets.aljam_password.path;
  };

  # Exempt from a restart/reload consumer: the hashed password is consumed by
  # user-account setup rather than a long-running service.
  sops.secrets.aljam_password = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true;
    owner = "aljam";
  };
}
