# Dedicated unprivileged account for remote Nix builds.
#
# Build clients connect as this user rather than an interactive
# administrative user.
#
# Security rules:
# - Use a dedicated build-only Ed25519 key for each build client.
# - Do not reuse an interactive root or administrative SSH key.
# - Every authorized key must use the SSH restrictions below.
# - `nix-builder` remains trusted only while remote builds require daemon
#   trust; revisit this before enabling distributed builds.
#
# Distributed builds are not enabled yet. To turn them on:
# 1. Generate a dedicated build-only Ed25519 key on each build client.
# 2. Add each public key above, wrapped with `restrictedKey`.
# 3. Verify `ssh -i <key> nix-builder@r820 true` from each client.
# 4. Configure `nix.distributedBuilds` and `nix.buildMachines` on the clients.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  builderKeys = config.users.users.nix-builder.openssh.authorizedKeys.keys;

  restrictedKey = key: "restrict,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ${key}";
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
  nix.settings.trusted-users = [ "nix-builder" ];

  assertions = [
    {
      assertion = !(config.nix.distributedBuilds or false) || builderKeys != [ ];
      message = "Distributed Nix builds require at least one authorized key for nix-builder.";
    }
  ];
}
