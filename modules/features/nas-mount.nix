# modules/features/nas-mount.nix
# NAS mount configuration with SOPS-managed CIFS credentials.
{ config, lib, pkgs, ... }:
{
  fileSystems = {
    "/mnt/share" = {
      device = "//${config.networking.fleet.nas.ip}/share";
      fsType = "cifs";
      options = [
        "credentials=${config.sops.secrets.nas-credentials.path}"
        "uid=1000"
        "gid=1000"
        "iocharset=utf-8"
        "noperm"
      ];
    };
  };

  # Exempt from a restart/reload consumer: this is a filesystem mount
  # credential. Restarting mounts automatically on credential rotation could
  # disrupt active workloads; remount manually after rotating credentials.
  sops.secrets.nas-credentials = {
    sopsFile = ../../secrets/nas.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };
}
