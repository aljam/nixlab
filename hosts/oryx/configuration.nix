{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/desktop-node.nix
    ../../modules/hardware/system76-laptop.nix
  ];

  # Allow Nix builds, including NixOS VM integration tests, to use KVM.
  # This requires Intel VT-x to be enabled in the host firmware.
  nix.settings.extra-sandbox-paths = [ "/dev/kvm" ];

  features.power-profiles.enable = true;
}
