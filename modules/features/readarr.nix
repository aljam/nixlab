{ config, lib, pkgs, ... }:

let
  bindAddr = config.servicesHostIP or "127.0.0.1";
in
{
  networking.proxyBackendPorts = [ 8787 ];

  services.readarr = {
    enable = true;
    group = "media";
  };

  # Ensure readarr user is in media group
  users.users.readarr.extraGroups = [ "media" ];

  # Fix permissions on activation (runs as root during rebuild)
  system.activationScripts.readarr-permissions.text = ''
    ${pkgs.coreutils}/bin/chown -R readarr:media /var/lib/readarr 2>/dev/null || true
    ${pkgs.coreutils}/bin/chmod -R 775 /var/lib/readarr 2>/dev/null || true
  '';
}
