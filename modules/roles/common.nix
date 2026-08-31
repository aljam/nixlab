# modules/roles/common.nix
# Common configuration for all machines
{ config, lib, pkgs, hostname, ... }:

{
  imports = [
    # Hardware-specific imports handled by host configurations
    ../features/boot.nix
    ../features/networking-options.nix
  ];

  options.networking.servicesBindAddress = lib.mkOption {
    type = lib.types.str;
    default =
      let
        host = config.networking.hostName;
      in
      if lib.hasAttrByPath [ host "ip" ] config.networking.fleet
      then config.networking.fleet.${host}.ip
      else "127.0.0.1";
    description = ''
      Address used by services that must be reachable by the local HAProxy instance.
    '';
  };

  # Configuration
  config = {
    system.stateVersion = lib.mkDefault "26.05";
    networking.hostName = hostname;
    networking.domain = config.networking.myDomain;
    
    nixpkgs.config.allowUnfree = true;
  
    # Locale and timezone
    time.timeZone = lib.mkDefault "America/Toronto";  # Or your timezone
    
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
  
    # Generate locales
    i18n.supportedLocales = [ "en_CA.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];

    # Enable flakes
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Set up cachix caches (keep your existing keys)
    nix.settings.substituters = [
      "https://cache.nixos.org"
      "https://aljam.cachix.org"
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://hyprland.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    nix.settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "aljam.cachix.org-1:E3E80fk8YEaTw0Y9V+0IHmhrvLQ/xACZ1VMXDZZ80oo="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];

    # SOPS for secrets
    sops.defaultSopsFile = ../../secrets/secrets.yaml;
    sops.defaultSopsFormat = "yaml";
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # SSH hardening
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        AllowUsers = [ "aljam" ];
        AllowGroups = [ "wheel" ];
      };
      # Only allow key-based auth for wheel
      extraConfig = ''
        Match Group wheel
          AuthenticationMethods publickey
      '';
    };

    # Fail2ban for SSH
    services.fail2ban = {
      enable = true;
      jails.sshd = {
        enabled = true;
        settings = {
          filter = "sshd";
          port = "ssh";
          logpath = "%(sshd_log)s";
        };
      };
    };

    # Users
    users.mutableUsers = false;

    # Common packages
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
