# modules/roles/common.nix
# Baseline configuration shared by every machine.
{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:

{
  imports = [
    # Hardware-specific imports are handled by host configurations.
    ../features/boot.nix
    ../features/networking-options.nix
    ../features/nix-cache.nix
    ../features/sops.nix
    ../features/ssh.nix
    ../features/security-policy.nix
  ];

  options.networking.servicesBindAddress = lib.mkOption {
    type = lib.types.str;
    default =
      let
        host = config.networking.hostName;
      in
      if lib.attrByPath [ host "ip" ] null config.networking.fleet != null then
        config.networking.fleet.${host}.ip
      else
        "127.0.0.1";
    description = ''
      Address used by services that must be reachable by the local HAProxy instance.
    '';
  };

  config = {
    system.stateVersion = lib.mkDefault "26.05";
    networking.hostName = hostname;
    networking.domain = config.networking.myDomain;

    nixpkgs.config.allowUnfree = true;

    time.timeZone = lib.mkDefault "America/Toronto";

    i18n.defaultLocale = lib.mkDefault "en_CA.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_CA.UTF-8";
      LC_IDENTIFICATION = "en_CA.UTF-8";
      LC_MEASUREMENT = "en_CA.UTF-8";
      LC_MONETARY = "en_CA.UTF-8";
      LC_NAME = "en_CA.UTF-8";
      LC_NUMERIC = "en_CA.UTF-8";
      LC_PAPER = "en_CA.UTF-8";
      LC_TELEPHONE = "en_CA.UTF-8";
      LC_TIME = "en_CA.UTF-8";
    };

    i18n.supportedLocales = [
      "en_CA.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    environment.systemPackages = [
      pkgs.git
      pkgs.vim
      pkgs.curl
      pkgs.wget
      pkgs.jq
      pkgs.ripgrep
      pkgs.fd
      pkgs.htop
      pkgs.btop
    ];
  };
}
