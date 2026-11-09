{ config, lib, pkgs, ... }:

let
  builderKeys = config.users.users.nix-builder.openssh.authorizedKeys.keys;

  restrictedKey = key: "restrict,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ${key}";

  unrestrictedBuilderKeys = lib.filter (
    key:
    !(lib.strings.hasPrefix "restrict," key)
    || !(lib.strings.hasInfix "no-port-forwarding" key)
    || !(lib.strings.hasInfix "no-agent-forwarding" key)
    || !(lib.strings.hasInfix "no-X11-forwarding" key)
  ) builderKeys;

  builderIsTrusted = lib.elem "nix-builder" (config.nix.settings.trusted-users or [ ]);
in
{
  users.users.nix-builder = {
    isNormalUser = true;
    description = "Remote Nix builder";
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      # Add dedicated build-client public keys here, wrapped with
      # `restrictedKey`:
      # (restrictedKey "ssh-ed25519 AAAA... nix-build-client")
    ];
  };

  # Required for remote builds to interact with the local Nix daemon.
  # Review this boundary before enabling distributed builds.
  nix.settings.trusted-users = lib.mkIf (config.nix.distributedBuilds or false) [ "nix-builder" ];

  assertions = [
    # Every builder key must be explicitly restricted. This prevents a build
    # client from obtaining port, agent, or X11 forwarding through SSH.
    {
      assertion = unrestrictedBuilderKeys == [ ];
      message = "Every nix-builder SSH key must use restrict, no-port-forwarding, no-agent-forwarding, and no-X11-forwarding.";
    }

    # Builder trust grants substantial authority over the Nix store. Keep it
    # disabled unless distributed builds are explicitly enabled.
    {
      assertion = !(config.nix.distributedBuilds or false) || builderIsTrusted;
      message = "Distributed Nix builds require nix-builder in nix.settings.trusted-users.";
    }

    {
      assertion = !(config.nix.distributedBuilds or false) || builderKeys != [ ];
      message = "Distributed Nix builds require at least one authorized key for nix-builder.";
    }
  ];
}
