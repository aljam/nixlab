{ config, pkgs, pkgs-stable, ... }:

{
  imports = [ ./modules/desktop/apps.nix
              ./modules/desktop/kitty.nix
              ./modules/desktop/obs.nix
            ];
 
  home.packages = with pkgs; [
    # --- KDE Plasma / Global Themes ---
    catppuccin-kde    
    arc-kde-theme     
    sweet-nova
    
    # --- Icon Themes ---
    papirus-icon-theme   
    tela-icon-theme      
    
    # --- Cursor Themes ---
    bibata-cursors      
    capitaine-cursors  
    
    # (Optional) Kvantum engine if you want deep widget theming
    # kdePackages.qtstyleplugin-kvantum

    # --- ArtCraft creative suite ---
    photocraft
    vectorcraft
    filmcraft
    lightcraft
    pdfcraft
    effectcraft
    designcraft
    cadcraft
    deckcraft
    gridcraft
    soundcraft
    wordcraft
  ];
  
 xdg.enable = true;
}
