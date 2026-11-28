{
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./gaming.nix
    ../../modules/roles/desktop-node.nix
    ../../modules/hardware/navi-desktop.nix
    ../../modules/features/power-profiles.nix
    ../../modules/features/huggingface-cli.nix
    ../../users/aljam/modules/features/deploy-keychain.nix
  ];

  programs.corectrl.enable = true; # AMD Overclocking/Undervolting

  # Allow Nix builds, including NixOS VM integration tests, to use KVM.
  # This requires SVM/AMD-V to be enabled in the host firmware.
  nix.settings.extra-sandbox-paths = [ "/dev/kvm" ];

  modules.features.power-profiles.enable = true;
  modules.features.huggingfaceCli.enable = true;

  networking.firewall.extraInputRules = ''
    # Allow the Prometheus host to scrape node exporter.
    ip saddr 192.168.1.2 tcp dport 9100 accept
  '';
}