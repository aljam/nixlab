{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode-desktop = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, sops-nix, home-manager, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, system, ... }: {
        checks = import ./tests { inherit pkgs; };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            treefmt
            sops
            age
            ssh-to-age
          ];
        };
      };

      flake = {
        nixosConfigurations = let
          mkHost = name: {
            modules = [
              ./hosts/${name}/configuration.nix
              sops-nix.nixosModules.sops
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.aljam = import ./users/aljam/home.nix;
                home-manager.extraSpecialArgs = { inherit inputs; };
              }
            ];
          };
        in
        {
          r820 = mkHost "r820";
          r730 = mkHost "r730";
          r730xd = mkHost "r730xd";
          navi = mkHost "navi";
        };
      };
    };
}
