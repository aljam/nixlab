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

        public-endpoint-inventory = import ./tests/public-endpoint-inventory.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };

        monitoring-coverage = import ./tests/monitoring-coverage.nix {
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

        alert-delivery = import ./tests/alert-delivery.nix {
          pkgs = nixpkgs.legacyPackages.${system};
        };
      };