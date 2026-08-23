{ config, lib, ... }:

{
  services.jellyfin = {
    enable = true;
    group = "media";
  };

  networking.proxyBackendPorts = [ 8096 ];

  # Add jellyfin user to media group
  users.users.jellyfin.extraGroups = [ "media" ];
}
