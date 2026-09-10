{ config, lib, pkgs, ... }:

let
  cfg = config.programs.gen1recomp;

  gen1recomp = pkgs.stdenvNoCC.mkDerivation {
    pname = "gen1recomp";
    version = cfg.version;

    src = pkgs.fetchurl {
      url =
        "https://github.com/bryanthaboi/gen1recomp/releases/download/"
        + "v${cfg.version}/gen1recomp-${cfg.version}.love";
      hash = cfg.hash;
    };

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    dontUnpack = true;

    installPhase = ''
      install -Dm644 "$src" \
        "$out/share/gen1recomp/gen1recomp.love"

      makeWrapper ${pkgs.love}/bin/love "$out/bin/gen1recomp" \
        --add-flags "$out/share/gen1recomp/gen1recomp.love"

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
    };

    hash = lib.mkOption {
      type = lib.types.str;
      description = "SRI hash of the Gen1Recomp .love release.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      gen1recomp
    ];
  };
}
