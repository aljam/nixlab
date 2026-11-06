{
  description = "Aljam's Unified Homelab Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";

    };

    artcraft = {
      url = "github:Hy4ri/artcraft-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver?host=gitlab.com";
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
      mailserver,
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
            commonModules { inherit hostname; }
            ++ [
              ./hosts/${hostname}/configuration.nix
              ./users/aljam/nixos.nix
              {
                system.configurationRevision = self.rev or self.dirtyRev or "";
              }
            ]
            ++ extraModules;
        };

      commonModules =
        { hostname }:
        [
          ./modules/roles/common.nix
          ./modules/features/deploy-user.nix

          sops-nix.nixosModules.sops
          nur.modules.nixos.default

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

          {
            roles.security.deployUser.enable = true;
          }

          {
            nixpkgs.overlays = [
              nix-cachyos-kernel.overlays.default
            ];
          }
        ];

      desktopModules = [
        {
          programs.appimage = {
            enable = true;
            binfmt = true;
            package = nixpkgs.legacyPackages.${system}.appimage-run.override {
              extraPkgs = pkgs: [
                pkgs.libxcrypt-legacy
                pkgs.libffi
                pkgs.libyaml
              ];
            };
          };

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

      hostConfigurations = {
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
          extraModules = [
            mailserver.nixosModules.mailserver
          ];
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

      deployHosts = builtins.attrNames hostConfigurations;
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;

      packages.${system} = {
        firewall-isolation =
          nixpkgs.legacyPackages.${system}.testers.runNixOSTest
            ./tests/firewall.nix;

        runtime-security = import ./tests/runtime-isolation.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };

        admin-isolation = import ./tests/runtime-isolation.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          test = "admin-isolation";
        };
      };

      apps.${system} = {
        deploy = {
          type = "app";
          meta.description = "Deploy NixOS configurations to one or more hosts.";
          program = "${nixpkgs.legacyPackages.${system}.writeShellScript "deploy-all" ''
            set -euo pipefail

            if [[ -n "$(git status --porcelain)" ]]; then
              echo "Refusing to deploy: Git working tree is dirty." >&2
              echo "Commit or stash changes, then retry." >&2
              exit 1
            fi

            echo "==> Running flake checks"
            nix --extra-experimental-features 'nix-command flakes' flake check --show-trace

            hosts=("$@")

            if (( ''${#hosts[@]} == 0 )); then
              hosts=(${lib.concatStringsSep " " deployHosts})
            fi

            for host in "''${hosts[@]}"; do
              valid=false
              for known in ${lib.concatStringsSep " " deployHosts}; do
                if [[ "''${host}" == "''${known}" ]]; then
                  valid=true
                  break
                fi
              done

              if [[ "''${valid}" != true ]]; then
                echo "Unknown deploy host: ''${host}" >&2
                echo "Available hosts: ${lib.concatStringsSep " " deployHosts}" >&2
                exit 1
              fi
            done

            for host in "''${hosts[@]}"; do
              echo "==> Deploying ''${host}"
              nixos-rebuild switch --flake ".#''${host}" --target-host "deploy@''${host}" --use-remote-sudo
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

        monitoring-health = import ./tests/runtime-isolation.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          test = "monitoring-health";
        };

        postgresql-auth = import ./tests/runtime-isolation.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          test = "postgresql-auth";
        };
      };

      nixosConfigurations = hostConfigurations;
    };
}
