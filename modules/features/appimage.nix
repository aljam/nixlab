{
  config, lib, pkgs, ...
}:
let
  cfg = config.programs.appimage;

  appimage-run = pkgs.appimage-run.override {
    extraPkgs = pkgs: [
      pkgs.libxcrypt-legacy
      pkgs.libffi
      pkgs.libyaml
    ];
  };
in
{
  options.programs.appimage = {
    enable = lib.mkEnableOption "AppImage execution with RPG Maker compatibility libraries";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      appimage-run
    ];
  };
}
