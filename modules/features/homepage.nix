{ config, lib, pkgs, ... }:

let
  cfg = config.modules.features.homepage;
in
{
  options.modules.features.homepage = {
    enable = lib.mkEnableOption "homepage dashboard";

    # The homepage is served by the NixOS host `navi` to maintain a consistent
    # service address across deployments.
    listenAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The address on which the homepage server listens. When null, the
        service binds to the host's configured servicesBindAddress.
      '';
    };

    # The homepage must be reachable from the local LAN to support
    # local network device discovery.
    allowedHosts = lib.mkOption {
      type = lib.types.str;
      default = "home.derezzed.info,${config.networking.fleet.navi.ip}:8082";
      description = ''
        Comma-separated list of hostnames and addresses that are permitted to
        access the homepage.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    roles.security.systemdHardenedServices = [ "homepage" ];

    services.homepage = {
      enable = true;
      listenAddress = lib.mkIf (cfg.listenAddress != null) cfg.listenAddress;
      allowedHosts = cfg.allowedHosts;
    };

    networking.firewall.extraInputRules = [
      "ip saddr ${config.networking.fleet.navi.ip} tcp dport 8082 accept"
    ];
  };
}