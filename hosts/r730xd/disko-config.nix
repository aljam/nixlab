{ lib, ... }:
let
  # Just paste your exact 24 WWN IDs from disks.txt into this list!
  rawDisks = [
    "wwn-0x5000c5007f451a73" # d1 (Gets ESP Boot Partition)
    "wwn-0x5000c5008e99ea37" # d2 (Gets ESP Boot Partition)
    "wwn-0x5000c50096e2ff63" # d3
    "wwn-0x5000c50096e321b3" # d4
    "wwn-0x5000c50096e325db" # d5
    "wwn-0x5000c50096e32813" # d6
    "wwn-0x5000c50096e32ea3" # d7
    "wwn-0x5000c50096e33a07" # d8
    "wwn-0x5000c50096e344bf" # d9
    "wwn-0x5000c50096e35663" # d10
    "wwn-0x5000c50096e367cf" # d11
    "wwn-0x5000c50096e375a7" # d12
    "wwn-0x5000c50096e38c1b" # d13
    "wwn-0x5000c50096e39893" # d14
    "wwn-0x5000cca07205e304" # d15
    "wwn-0x5000cca07206d234" # d16
    "wwn-0x5000cca07206d534" # d17
    "wwn-0x5000cca0720ab328" # d18
    "wwn-0x5000cca0720bd88c" # d19
    "wwn-0x5000cca0720c2ee8" # d20
    "wwn-0x5000cca0720ceedc" # d21
    "wwn-0x5000cca0720dc4cc" # d22
    "wwn-0x5000cca0720ddd40" # d23
    "wwn-0x5000cca0720dde80" # d24
  ];

  # This function automatically writes the boilerplate for every single drive
  makeDisk =
    index: wwn:
    lib.nameValuePair "d${toString index}" {
      type = "disk";
      device = "/dev/disk/by-id/${wwn}";
      content = {
        type = "gpt";
        partitions =
          # Only add the UEFI boot partition to the first two disks
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
                  pool = "mediapool";
                };
              };
            }
          # All other 22 disks are dedicated 100% to ZFS
          else
            {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "mediapool";
                };
              };
            };
      };
    };

in
{
  boot.zfs.devNodes = "/dev/disk/by-id";

  disko.devices = {
    # Dynamically generate "d1" through "d24" using our list
    disk = builtins.listToAttrs (lib.imap1 makeDisk rawDisks);

    zpool = {
      mediapool = {
        type = "zpool";
        mode = {
          topology = {
            type = "topology";
            vdev = [
              {
                mode = "raidz2";
                members = [
                  "d1"
                  "d2"
                  "d3"
                  "d4"
                  "d5"
                  "d6"
                  "d7"
                  "d8"
                ];
              }
              {
                mode = "raidz2";
                members = [
                  "d9"
                  "d10"
                  "d11"
                  "d12"
                  "d13"
                  "d14"
                  "d15"
                  "d16"
                ];
              }
              {
                mode = "raidz2";
                members = [
                  "d17"
                  "d18"
                  "d19"
                  "d20"
                  "d21"
                  "d22"
                  "d23"
                  "d24"
                ];
              }
            ];
          };
        };
        rootFsOptions = {
          compression = "zstd";
          atime = "off";
          mountpoint = "none";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          media = {
            type = "zfs_fs";
            mountpoint = "/mnt/media";
          };
        };
      };
    };
  };
}
