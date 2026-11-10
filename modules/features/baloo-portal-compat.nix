# Compatibility desktop entry for Baloo.
#
# xdg-desktop-portal may log:
#   Could not register app ID: App info not found for 'org.kde.baloo'
# because Baloo does not provide a matching desktop entry. This entry gives
# the portal an application identity without exposing Baloo in application
# launchers.
{
  environment.etc."xdg/applications/org.kde.baloo.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=KDE Baloo
    Exec=baloo_file_extractor %U
    NoDisplay=true
  '';
}
