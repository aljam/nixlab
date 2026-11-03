{ config, pkgs, ... }:

{
  users.users.aljam = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0Y44h2FhGd7E8jXp3kZ0Y9M6B1uJ4tS7vQ2wE5rT8y aljam@navi"
    ];
    hashedPasswordFile = config.sops.secrets.aljam_password.path;
  };

  sops.secrets.aljam_password = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true;
  };
}