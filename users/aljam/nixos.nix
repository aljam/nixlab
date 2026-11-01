{ config, pkgs, lib, ... }:

let
  groupExists = g: builtins.hasAttr g config.users.groups;
in
{
  users.users.aljam = {
    extraGroups =
      [ "wheel" "video" "render" "input" ]
      ++ lib.filter groupExists [
        "networkmanager"
        "libvirtd"
        "wireshark"
        "media"
        "podman"
      ];
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHzrMiro1XD8krk5Kb4EWQ+rGjmgKXha/OuOmUZcopRL navi-desktop"
    ];
    shell = pkgs.fish;
    hashedPasswordFile = config.sops.secrets.aljam_password.path;
  };

  programs.fish.enable = true;

  sops.secrets.aljam_password = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true; # required — decrypt before user creation
    owner = "root";
    group = "root";
    mode = "0400";
  };
}
