{ config, pkgs, subnets, ... }:

{
  nix = {
    distributedBuilds = true;

    # Optional: Don't force builds to the remote if local is faster for tiny packages
    settings.builders-use-substitutes = true;

    buildMachines = [{
      hostName = "${config.networking.subnets.lan}.4";
      system = "x86_64-linux";
      protocol = "ssh"; # The modern, faster Nix SSH protocol

      # Dedicated unprivileged builder account; do not use an interactive
      # administrative user for remote builds.
      sshUser = "nix-builder";

      # The SSH key that the local nix-daemon (root) will use to connect
      sshKey = "/root/.ssh/id_ed25519";

      # The R820 is a massive quad-socket server, let it chew through heavy jobs!
      maxJobs = 32;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" ];
    }];
  };
}
