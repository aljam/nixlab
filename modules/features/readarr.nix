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

  users.users.readarr.extraGroups = [ "media" ];

  system.activationScripts.readarr-permissions.text = ''
    ${pkgs.coreutils}/bin/chown -R readarr:media /var/lib/readarr 2>/dev/null || true
    ${pkgs.coreutils}/bin/chmod -R 775 /var/lib/readarr 2>/dev/null || true
  '';

  systemd.services.readarr.serviceConfig.ExecStartPre = lib.mkForce [];
}
