{ lib, ... }:
let
  rawDisks = [
    "wwn-0x5000c5007dd3fee3" # d1
    "wwn-0x5000c5007dd70cb7" # d2
    "wwn-0x5000c5007de11ecb" # d3
    "wwn-0x5000c5007f119817" # d4
    "wwn-0x5000c5007f1268cb" # d5
    "wwn-0x5000c5007f138ae3" # d6
    "wwn-0x5000c5008f0364e3" # d7
    "wwn-0x5000c5008f0517e3" # d8
  ];

  makeDisk =
    index: wwn:
    lib.nameValuePair "d${toString index}" {
      type = "disk";
      device = "/dev/disk/by-id/${wwn}";
      content = {
        type = "gpt";
        partitions =
          if (index == 1 || index == 2) then
            {
              ESP = {
                size = "500M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = if index == 1 then "/boot" else "/boot2";
                };
              };
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "r730pool";
                };
              };
            }
          else
            {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "r730pool";
                };
              };
            };
      };
    };

in
{
  boot.zfs.devNodes = "/dev/disk/by-id";

  disko.devices = {
    disk = builtins.listToAttrs (lib.imap1 makeDisk rawDisks);

    zpool = {
      r730pool = {
        type = "zpool";
        mode = {
          topology = {
            type = "topology";
            vdev = [
              {
                mode = "mirror";
                members = [
                  "d1"
                  "d2"
                ];
              }
              {
                mode = "mirror";
                members = [
                  "d3"
                  "d4"
                ];
              }
              {
                mode = "mirror";
                members = [
                  "d5"
                  "d6"
                ];
              }
              {
                mode = "mirror";
                members = [
                  "d7"
                  "d8"
                ];
              }
            ];
          };
        };
        rootFsOptions = {
          compression = "lz4";
          mountpoint = "none";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
          };
        };
      };
    };
  };
}
