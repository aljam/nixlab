{
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./gaming.nix
    ../../modules/roles/desktop-node.nix
    ../../modules/hardware/system76-laptop.nix
    ../../modules/features/power-profiles.nix
    ../../users/aljam/modules/features/deploy-keychain.nix
  ];

  # Allow Nix builds, including NixOS VM integration tests, to use KVM.
  # This requires Intel VT-x to be enabled in the host firmware.
  nix.settings.extra-sandbox-paths = [ "/dev/kvm" ];

  modules.features.power-profiles.enable = true;
  modules.features.tailscale-health.enable = true;
  services.power-profiles-daemon.enable = lib.mkForce true;

  networking.firewall.extraInputRules = ''
    # Allow the Prometheus host to scrape node exporter.
    ip saddr 192.168.1.2 tcp dport 9100 accept
  '';
}
