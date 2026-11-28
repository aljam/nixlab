{ config, lib, pkgs, ... }:

let
  cfg = config.modules.features.qwen-inference;
in
{
  options.modules.features.qwen-inference = {
    enable = lib.mkEnableOption "Qwen inference server";

    # The Qwen inference server is served by the NixOS host `oryx`.
    listenAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The address on which the Qwen inference server listens. When null, the
        service binds to the host's configured servicesBindAddress.
      '';
    };

    # The Qwen inference server must be reachable from the local LAN to support
    # local network device discovery.
    allowedHosts = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.fleet.oryx.ip}:8000";
      description = ''
        Comma-separated list of hostnames and addresses that are permitted to
        access the Qwen inference server.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    roles.security.systemdHardenedServices = [ "qwen-inference" ];

    services.qwen-inference = {
      enable = true;
      listenAddress = lib.mkIf (cfg.listenAddress != null) cfg.listenAddress;
      allowedHosts = cfg.allowedHosts;
    };

    networking.firewall.extraInputRules = [
      "ip saddr ${config.networking.fleet.oryx.ip} tcp dport 8000 accept"
    ];
  };
}