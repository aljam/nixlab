{ config, lib, pkgs, ... }:
let
  cfg = config.modules.features.libvirt;
in
{
  options.modules.features.libvirt = {
    gui.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install virt-manager for local graphical VM management.";
    };

    remoteManagement.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable libvirt for remote management over SSH.";
    };

    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users allowed to manage libvirt VMs.";
    };
  };

  config = lib.mkMerge [
    {
      virtualisation.libvirtd = {
        enable = true;
        qemu.swtpm.enable = true;
        qemu.package = pkgs.qemu_kvm;
        allowedBridges = [ "virbr0" ];
      };
    }

    (lib.mkIf cfg.gui.enable {
      programs.virt-manager.enable = true;
    })

    (lib.mkIf cfg.remoteManagement.enable {
      # libvirt is managed over SSH; no additional listening service is required.
      services.openssh.enable = true;
    })

    (lib.mkIf (cfg.adminUsers != []) {
      users.users = lib.listToAttrs (map (name: {
        name = name;
        value = {
          extraGroups = [ "libvirtd" ];
        };
      }) cfg.adminUsers);
    })
  ];
}
