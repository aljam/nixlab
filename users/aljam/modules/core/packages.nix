{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bat
    eza
    fzf
    ripgrep
    jq
    tldr
    fd
    lazygit
    btop
    ncdu
    fastfetch
    gh
    sops
    gcc
    gnumake
    unzip
    xclip
    gnupg
  ];
}
