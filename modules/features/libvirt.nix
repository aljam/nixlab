{ config, pkgs, ... }:

{
  # --- Virtualisation & KVM ---
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.swtpm.enable = true;
  virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;

  # GUI frontend for libvirtd
  programs.virt-manager.enable = true;

  # Let NixOS natively handle the default network without blocking activation scripts
  virtualisation.libvirtd.allowedBridges = [ "virbr0" ];
}
