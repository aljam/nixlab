{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Font configuration for the system
  fonts = {
    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultPackages = true;

    # Modern NixOS (23.11+) uses `fonts.packages` instead of `fonts.fonts`
    packages = with pkgs; [
      # Standard essential fonts
      noto-fonts
      noto-fonts-cjk-sans # Chinese, Japanese, Korean
      noto-fonts-color-emoji
      liberation_ttf
      corefonts # Microsoft Arial, Times New Roman, etc.

      nerd-fonts.fira-code
      nerd-fonts.meslo-lg
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
    ];

    # System-wide default font configurations
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [
          "Noto Serif"
          "Liberation Serif"
        ];
        sansSerif = [
          "Noto Sans"
          "Ubuntu"
          "Liberation Sans"
        ];
        monospace = [
          "JetBrainsMono Nerd Font"
          "FiraCode Nerd Font"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
