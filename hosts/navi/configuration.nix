{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/desktop-node.nix
    ../../modules/hardware/navi-desktop.nix
  ];

  programs.corectrl.enable = true; # AMD Overclocking/Undervolting

  # Allow Nix builds, including NixOS VM integration tests, to use KVM.
  # This requires SVM/AMD-V to be enabled in the host firmware.
  nix.settings.extra-sandbox-paths = [ "/dev/kvm" ];
}
