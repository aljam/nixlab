{ config, pkgs, ... }:

{
  # Enable Sanoid for automated snapshotting and pruning
  services.sanoid = {
    enable = true;
    interval = "*:0/15"; # Run snapshot checks every 15 minutes

    # Define your retention templates
    templates.storage = {
      hourly = 24;
      daily = 7;
      monthly = 3;
      yearly = 0;
      autosnap = true;
      autoprune = true;
    };

    # Apply templates to your ZFS pools (Adjust pool/dataset names to match yours)
    datasets = {
      "mediapool/media" = {
        useTemplate = [ "storage" ];
        recursive = true;
      };
      "mediapool/root" = {
        useTemplate = [ "storage" ];
        recursive = true;
      };
    };
  };
}
