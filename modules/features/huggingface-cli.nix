{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.modules.features.huggingfaceCli = {
    enable = lib.mkEnableOption "Hugging Face CLI";
  };

  config = lib.mkIf config.modules.features.huggingfaceCli.enable {
    environment.systemPackages = [
      pkgs.python3Packages.huggingface-hub
    ];
  };
}
