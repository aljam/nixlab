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

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
    };

    nur = {
      url = "github:nix-community/NUR";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      plasma-manager,
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

      pkgs = nixpkgs.legacyPackages.${system};

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      stablePackages = {
        lutris = pkgs-stable.lutris;
      };

      mkHost =
        {
          hostname,
          extraModules ? [ ],
        }:
        lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit inputs stablePackages hostname;
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
          ./modules/features/nix-gc
          ./modules/roles/common.nix
          ./modules/features/deploy-user.nix

          sops-nix.nixosModules.sops

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.aljam = import ./users/aljam/home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs stablePackages hostname;
            };
          }

          {
            roles.security.deployUser.enable = true;
          }

          {
            modules.features.nix-gc = {
              enable = true;
              schedule = "Sun 03:00";

              retention = {
                generations = 4;
                age = "14 days";
              };
            };
          }
        ];

      desktopModules = [
        ./modules/features/baloo-portal-compat.nix
        ./modules/features/streamdeck.nix
        ./modules/features/hyprland.nix

        {
          features.streamdeck.enable = true;

          modules.features.nix-gc = {
            retention = {
              generations = 8;
              age = "30 days";
            };
          };

          home-manager.sharedModules = [
            plasma-manager.homeModules.plasma-manager
          ];

          home-manager.users.aljam.programs.plasma.enable = true;

          programs.appimage = {
            enable = true;
            binfmt = true;
            package = pkgs.appimage-run.override {
              extraPkgs = pkgs: [
                pkgs.libxcrypt-legacy
                pkgs.libffi
                pkgs.libyaml
              ];
            };
          };

          nixpkgs.overlays = [
            nix-cachyos-kernel.overlays.default
            artcraft.overlays.default
          ];

          home-manager.users.aljam.imports = [
            ./users/aljam/home-gui.nix
            ./users/aljam/modules/desktop/hyprland.nix
          ];
        }

        nix-flatpak.nixosModules.nix-flatpak
        nur.modules.nixos.default
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
          extraModules = [ ];
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

      deployHosts = [
        "r820"
        "r730"
        "r730xd"
      ];
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;

      packages.${system} = {
        firewall-isolation = pkgs.testers.runNixOSTest ./tests/firewall.nix;

        admin-isolation = import ./tests/runtime-isolation.nix {
          pkgs = pkgs;
          test = "admin-isolation";
        };
      };

      apps.${system} = {
        deploy = {
          type = "app";
          meta.description = "Deploy a pushed revision of this flake to one or more hosts.";
          program = "${pkgs.writeShellScript "deploy-all" ''
            set -euo pipefail

            deployKey="''${NIXLAB_DEPLOY_KEY:-$HOME/.ssh/nixlab_deploy}"
            known_hosts=(${lib.concatStringsSep " " deployHosts})

            if [[ -n "$(git status --porcelain)" ]]; then
              echo "Refusing to deploy: Git working tree is dirty." >&2
              echo "Commit or stash changes, then retry." >&2
              exit 1
            fi

            rev="$(git rev-parse HEAD)"

            if [[ ! "$rev" =~ ^[0-9a-f]{40}$ ]]; then
              echo "Refusing to deploy: unable to resolve a full commit SHA." >&2
              exit 1
            fi

            git fetch --quiet origin
            if [[ "$rev" != "$(git rev-parse origin/main)" ]]; then
              echo "Refusing to deploy: HEAD ($rev) is not the tip of origin/main" >&2
              exit 1
            fi

            echo "==> Running flake checks"
            nix --extra-experimental-features 'nix-command flakes' flake check --show-trace

            hosts=("$@")
            if (( ''${#hosts[@]} == 0 )); then
              hosts=("''${known_hosts[@]}")
            fi

            for host in "''${hosts[@]}"; do
              echo "==> Deploying ''${host} @ ''${rev}"
              ssh -i "$deployKey" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 "deploy@''${host}" "deploy-rebuild switch ''${rev}"
            done
          ''}";
        };

        deploy-plan = {
          type = "app";
          meta.description = "Validate and print the hosts that deploy would target without connecting or switching.";
          program = "${pkgs.writeShellScript "deploy-plan" ''
            set -euo pipefail

            known_hosts=(${lib.concatStringsSep " " deployHosts})

            if [[ -n "$(git status --porcelain)" ]]; then
              echo "Refusing to deploy: Git working tree is dirty." >&2
              echo "Commit or stash changes, then retry." >&2
              exit 1
            fi

            rev="$(git rev-parse HEAD)"

            if [[ ! "$rev" =~ ^[0-9a-f]{40}$ ]]; then
              echo "Refusing to deploy: unable to resolve a full commit SHA." >&2
              exit 1
            fi

            git fetch --quiet origin
            if [[ "$rev" != "$(git rev-parse origin/main)" ]]; then
              echo "Refusing to deploy: HEAD ($rev) is not the tip of origin/main" >&2
              exit 1
            fi

            echo "==> Running flake checks"
            nix --extra-experimental-features 'nix-command flakes' flake check --show-trace

            hosts=("$@")
            if (( ''${#hosts[@]} == 0 )); then
              hosts=("''${known_hosts[@]}")
            fi

            echo "==> Deployment plan"
            echo "Revision: $rev"
            echo "Hosts:"
            for host in "''${hosts[@]}"; do
              echo "  - $host"
            done
            echo "No hosts were connected to or switched."
          ''}";
        };

        deploy-status = {
          type = "app";
          meta.description = "Report whether deploy hosts are running the current main revision without switching.";
          program = "${pkgs.writeShellScript "deploy-status" ''
            set -euo pipefail

            deployKey="''${NIXLAB_DEPLOY_KEY:-$HOME/.ssh/nixlab_deploy}"
            known_hosts=(${lib.concatStringsSep " " deployHosts})

            usage() {
              echo "Usage: deploy-status [--json] [--quiet] [HOST...]" >&2
              echo "Revision: $rev"
              echo
              printf '%-12s %-12s %s\\n' "Host" "Status" "Running revision"
            }

            output="human"
            hosts=()

            for arg in "$@"; do
              case "$arg" in
                --json)
                  output="json"
                  ;;
                --quiet)
                  output="quiet"
                  ;;
                -h|--help)
                  usage
                  exit 0
                  ;;
                --*)
                  hosts+=("$arg")
                  ;;
              esac
            done

            if [[ "$output" == "json" ]]; then
              printf '{"revision":"%s","hosts":[' "$rev"
            elif [[ "$output" == "human" ]]; then
              echo "==> Deployment status"
              echo
              printf '%-12s %-12s %s\\n' "Host" "Status" "Running revision"
            fi

            first=1
            for host in "$@"; do
              if running="$(ssh -i "$deployKey" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 "deploy@''${host}" "nixos-version --configuration-revision" 2>/dev/null)"; then
                if [[ "$running" == "$rev" ]]; then
                  status="up-to-date"
                  up_to_date=$((up_to_date + 1))
                else
                  status="out-of-date"
                  out_of_date=$((out_of_date + 1))
                fi
              else
                status="unreachable"
                running=""
                unreachable=$((unreachable + 1))
              fi

              case "$output" in
                json)
                  if (( first == 0 )); then
                    printf ','
                  fi
                  printf '{"host":"%s","status":"%s","runningRevision":"%s"}' \\
                    "$host" "$status" "$running"
                  first=0
                  ;;
                human)
                  printf '%-12s %-12s %s\\n' "$host" "$status" "$running"
                  ;;
              esac
            done

            if [[ "$unreachable" > 0 ]]; then
              exit 2
            fi

            if [[ "$out_of_date" > 0 ]]; then
              exit 1
            fi

            exit 0
          ''}";
        };
      };

      checks.${system} = {
        nix-gc-policy = pkgs.testers.runNixOSTest ./tests/nix-gc-policy.nix;

        deployment-freshness = pkgs.testers.runNixOSTest ./tests/deployment-freshness.nix;

        alert-routing = import ./tests/alert-routing.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        power-profiles = import ./tests/power-profiles.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        disk-health = import ./tests/disk-health.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        backup-assurance = import ./tests/backup-assurance.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        restic-replication = import ./tests/restic-replication.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        nftables-input-rules = import ./tests/nftables-input-rules.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        service-exposure = import ./tests/service-exposure.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        public-service-hardening = import ./tests/public-service-hardening.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        public-endpoint-inventory = import ./tests/public-endpoint-inventory.nix {
          pkgs = pkgs;
        };

        public-service-recovery-drill = import ./tests/public-service-recovery-drill.nix {
          pkgs = pkgs;
        };

        monitoring-coverage = import ./tests/monitoring-coverage.nix {
          pkgs = pkgs;
          hosts = self.nixosConfigurations;
        };

        monitoring-health = import ./tests/runtime-isolation.nix {
          pkgs = pkgs;
          test = "monitoring-health";
        };

        nix-gc-observability = pkgs.testers.runNixOSTest ./tests/nix-gc-observability.nix;

        postgresql-auth = import ./tests/runtime-isolation.nix {
          pkgs = pkgs;
          test = "postgresql-auth";
        };

        servarr-media-access = pkgs.testers.runNixOSTest ./tests/servarr-media-access.nix;

        host-rebuild-recovery-drill = import ./tests/host-rebuild-recovery-drill.nix {
          pkgs = pkgs;
        };

        loki-restore-drill = import ./tests/loki-restore-drill.nix {
          pkgs = pkgs;
        };

        alertmanager-restore-drill = import ./tests/alertmanager-restore-drill.nix {
          pkgs = pkgs;
        };

        prometheus-restore-drill = import ./tests/prometheus-restore-drill.nix {
          pkgs = pkgs;
        };

        grafana-restore-drill = import ./tests/grafana-restore-drill.nix {
          pkgs = pkgs;
        };

        radio-restore-drill = import ./tests/radio-restore-drill.nix {
          pkgs = pkgs;
        };

        shoko-restore-drill = import ./tests/shoko-restore-drill.nix {
          pkgs = pkgs;
        };

        jellyseerr-restore-drill = import ./tests/jellyseerr-restore-drill.nix {
          pkgs = pkgs;
        };

        prowlarr-restore-drill = import ./tests/prowlarr-restore-drill.nix {
          pkgs = pkgs;
        };

        bazarr-restore-drill = import ./tests/bazarr-restore-drill.nix {
          pkgs = pkgs;
        };

        lidarr-restore-drill = import ./tests/lidarr-restore-drill.nix {
          pkgs = pkgs;
        };

        sonarr-radarr-restore-drill = import ./tests/sonarr-radarr-restore-drill.nix {
          pkgs = pkgs;
        };

        qbittorrent-restore-drill = import ./tests/qbittorrent-restore-drill.nix {
          pkgs = pkgs;
        };

        media-stack-restore-drill = import ./tests/media-stack-restore-drill.nix {
          pkgs = pkgs;
        };

        jellyfin-restore-drill = import ./tests/jellyfin-restore-drill.nix {
          pkgs = pkgs;
        };

        homepage-restore-drill = import ./tests/homepage-restore-drill.nix {
          pkgs = pkgs;
        };

        postgresql-database-isolation = import ./tests/postgresql-database-isolation.nix {
          pkgs = pkgs;
        };

        postgresql-restore-drill = import ./tests/postgresql-restore-drill.nix {
          pkgs = pkgs;
        };

        matrix-restore-drill = import ./tests/matrix-restore-drill.nix {
          pkgs = pkgs;
        };

        vaultwarden-restore-drill = import ./tests/vaultwarden-restore-drill.nix {
          pkgs = pkgs;
        };

        peertube-restore-drill = import ./tests/peertube-restore-drill.nix {
          pkgs = pkgs;
        };

        alert-delivery = import ./tests/alert-delivery.nix {
          pkgs = pkgs;
        };

        deploy-guard = import ./tests/deploy-guard.nix {
          pkgs = pkgs;
          deployScript = self.apps.${system}.deploy.program;
        };

        deploy-behavior = import ./tests/deploy-behavior.nix {
          pkgs = pkgs;
          deployScript = self.apps.${system}.deploy.program;
          inherit deployHosts;
        };

        sops-recovery = import ./tests/sops-recovery.nix {
          lib = nixpkgs.lib;
          pkgs = pkgs;
        };

        drift-detection = pkgs.testers.runNixOSTest ./tests/drift-detection.nix;

        storage-capacity = pkgs.testers.runNixOSTest ./tests/storage-capacity.nix;

        upstream-network = pkgs.testers.runNixOSTest ./tests/upstream-network.nix;
      };

      nixosConfigurations = hostConfigurations;
    };
}
