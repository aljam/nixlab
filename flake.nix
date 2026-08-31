{
  description = "Aljam's Unified Homelab Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-26.05";
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

    hyprland = { url = "github:hyprwm/Hyprland"; inputs.nixpkgs.follows = "nixpkgs"; };

    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    disko,
    sops-nix,
    mailserver,
    nix-cachyos-kernel,
    millennium,
    nur,
    ...
  }@inputs:
    let
      system = "x86_64-linux";

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      mkHost = { hostname, extraModules ? [] }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-stable hostname; };

        modules = [
          ./hosts/${hostname}/configuration.nix
          ./modules/roles/common.nix
          ./users/aljam/nixos.nix
          sops-nix.nixosModules.sops
          nur.modules.nixos.default
          (
            { pkgs, ... }:
            {
              nixpkgs.overlays = [
                nix-cachyos-kernel.overlays.pinned
              ];
            }
          )

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.aljam = import ./users/aljam/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs pkgs-stable hostname; };
          }
        ] ++ extraModules;
      };

      desktop = { home-manager.users.aljam.imports = [ ./users/aljam/home-gui.nix ]; };
      flatpakModule = inputs.nix-flatpak.nixosModules.nix-flatpak;

    in {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      checks.${system} = {
        # Fast and VM-free: checks the shape of every custom nftables input rule
        # on every host. Runs anywhere, including in `nix flake check` on CI.
        nftables-input-rules = import ./tests/nftables-input-rules.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          hosts = self.nixosConfigurations;
        };

        # End-to-end: boots a gateway, a backend, a Prometheus server and an
        # unprivileged LAN client, and proves the isolation actually holds.
        firewall-isolation =
          nixpkgs.legacyPackages.${system}.testers.runNixOSTest ./tests/firewall.nix;
      };

      nixosConfigurations = {

        navi = mkHost {
          hostname = "navi";
          extraModules = [ desktop flatpakModule ];
        };

        oryx = mkHost {
          hostname = "oryx";
          extraModules = [
            desktop
            flatpakModule
            inputs.nixos-hardware.nixosModules.system76
          ];
        };

        r820 = mkHost {
          hostname = "r820";
        };

        r730 = mkHost {
          hostname = "r730";
          extraModules = [ disko.nixosModules.disko ];
        };

        r730xd = mkHost {
          hostname = "r730xd";
          extraModules = [ disko.nixosModules.disko ];
        };

      };
    };
}
