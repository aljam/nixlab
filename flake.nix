{
  description = "Aljam's Unified Homelab Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    artcraft.url = "github:Hy4ri/artcraft-flake";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      disko,
      sops-nix,
      nix-cachyos-kernel,
      nur,
      artcraft,
      nix-flatpak,
      nixos-hardware,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      mkHost =
        {
          hostname,
          extraModules ? [ ],
        }:
        lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit inputs pkgs-stable hostname;
          };

          modules =
            commonModules
            ++ [
              ./hosts/${hostname}/configuration.nix
              ./users/aljam/nixos.nix

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.users.aljam = import ./users/aljam/home.nix;
                home-manager.extraSpecialArgs = {
                  inherit inputs pkgs-stable hostname;
                };
              }
            ]
            ++ extraModules;
        };

      commonModules = [
        ./modules/roles/common.nix

        sops-nix.nixosModules.sops
        nur.modules.nixos.default

        {
          nixpkgs.overlays = [
            nix-cachyos-kernel.overlays.default
          ];
        }
      ];

      desktopModules = [
        {
          nixpkgs.overlays = [
            artcraft.overlays.default
          ];

          home-manager.users.aljam.imports = [
            ./users/aljam/home-gui.nix
          ];
        }

        nix-flatpak.nixosModules.nix-flatpak
      ];

      diskoModule = disko.nixosModules.disko;

      deployHosts = [
        "navi"
        "oryx"
        "r820"
        "r730"
        "r730xd"
      ];
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;

      apps.${system} = {
        deploy = {
          type = "app";
          program = "${nixpkgs.legacyPackages.${system}.writeShellScript "deploy-all" ''
            set -euo pipefail

            hosts=("$@")

            if (( ''${#hosts[@]} == 0 )); then
              hosts=(${lib.concatStringsSep " " deployHosts})
            fi

            for host in "''${hosts[@]}"; do
              echo "==> Deploying ''${host}"
              nixos-rebuild switch \\
                --flake ".#''${host}" \\
                --target-host "root@''${host}" \\
                --use-remote-sudo
            done
          ''}";
        };
      };

      checks.${system} = {
        nftables-input-rules = import ./tests/nftables-input-rules.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          hosts = self.nixosConfigurations;
        };

        service-exposure = import ./tests/service-exposure.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          hosts = self.nixosConfigurations;
        };

        public-service-hardening = import ./tests/public-service-hardening.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          hosts = self.nixosConfigurations;
        };

        runtime-security = import ./tests/runtime-security.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };

        admin-isolation = import ./tests/runtime-isolation.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          test = "admin-isolation";
        };

        monitoring-health = import ./tests/runtime-isolation.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          test = "monitoring-health";
        };

        postgresql-auth = import ./tests/runtime-isolation.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          test = "postgresql-auth";
        };

        firewall-isolation =
          nixpkgs.legacyPackages.${system}.testers.runNixOSTest
            ./tests/firewall.nix;
      };

      nixosConfigurations = {
        navi = mkHost {
          hostname = "navi";
          extraModules = desktopModules;
        };

        oryx = mkHost {
          hostname = "oryx";
          extraModules = desktopModules ++ [
            nixos-hardware.nixosModules.system76
          ];
        };

        r820 = mkHost {
          hostname = "r820";
        };

        r730 = mkHost {
          hostname = "r730";
          extraModules = [ diskoModule ];
        };

        r730xd = mkHost {
          hostname = "r730xd";
          extraModules = [ diskoModule ];
        };
      };
    };
}
