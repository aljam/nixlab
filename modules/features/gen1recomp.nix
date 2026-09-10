{ config, lib, pkgs, ... }:

let
  cfg = config.programs.gen1recomp;

  gen1recomp = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "gen1recomp";
    version = cfg.version;

    src = pkgs.fetchurl {
      url = "https://github.com/bryanthaboi/gen1recomp/releases/download/v${version}/gen1recomp-${version}.love";
      hash = cfg.hash;
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm644 "$src" "$out/share/gen1recomp/gen1recomp.love"

      mkdir -p "$out/bin"
      cat > "$out/bin/gen1recomp" <<'EOF'
      #!${pkgs.runtimeShell}
      exec ${pkgs.love}/bin/love \
        "$out/share/gen1recomp/gen1recomp.love" "$@"
      EOF
      chmod +x "$out/bin/gen1recomp"

      install -Dm644 ${./gen1recomp.desktop} \
        "$out/share/applications/gen1recomp.desktop"
    '';
  };
in
{
  options.programs.gen1recomp = {
    enable = lib.mkEnableOption "Gen1Recomp";

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.2.57";
      description = "Gen1Recomp release version.";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      description = ''
        SRI hash of the Gen1Recomp .love release artifact.
        Obtain it with:
          nix store prefetch-file <release-url>
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      gen1recomp
      pkgs.love
    ];

    environment.etc."gen1recomp-version".text = cfg.version;
  };
}
