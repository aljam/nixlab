{ config, pkgs, ... }:

let
  obs-retro-effects-fixed = pkgs.obs-studio-plugins.obs-retro-effects.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/obs-utils.c \
        --replace-fail "char *pos = strrchr(file_name, '/');" \
                       "const char *pos = strrchr(file_name, '/');"
    '';
  });
in
{
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
      input-overlay
      obs-command-source
      obs-retro-effects-fixed
    ];
  };

  home.packages = [ 
    pkgs.streamcontroller 
  ];
}
