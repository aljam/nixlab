{
  pkgs,
  ...
}:

{
  programs.gamemode = {
    enable = true;

    settings = {
      general.renice = 10;

      custom = {
        start = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
        end = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced";
      };
    };
  };
}
