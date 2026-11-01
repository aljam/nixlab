{ config, pkgs, subnets, ... }:

# TODO: Re-enable remote builds after completing builder setup:
# 1. Generate or identify each build client's root SSH key.
# 2. Add each client's root public key to `users.users.nix-builder.openssh.authorizedKeys.keys`
#    in `modules/features/nix-builder.nix` on r820.
# 3. Verify `ssh -i /root/.ssh/id_ed25519 nix-builder@r820 true` from each client.
# 4. Re-enable the configuration below.
{
  # nix = {
  #   distributedBuilds = true;
  #
  #   # Optional: Don't force builds to the remote if local is faster for tiny packages
  #   settings.builders-use-substitutes = true;
  #
  #   buildMachines = [{
  #     hostName = "${config.networking.subnets.lan}.4";
  #     system = "x86_64-linux";
  #     protocol = "ssh"; # The modern, faster Nix SSH protocol
  #
  #     # Dedicated unprivileged builder account; do not use an interactive
  #     # administrative user for remote builds.
  #     sshUser = "nix-builder";
  #
  #     # The SSH key that the local nix-daemon (root) will use to connect
  #     sshKey = "/root/.ssh/id_ed25519";
  #
  #     # The R820 is a massive quad-socket server, let it chew through heavy jobs!
  #     maxJobs = 32;
  #     speedFactor = 2;
  #     supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" ];
  #   }];
  # };
}
