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
      weekly = 4;
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

  # Sanoid requires ZFS privileges and host filesystem visibility, so avoid
  # NoNewPrivileges and ProtectSystem=strict here.
  systemd.services.sanoid.serviceConfig = {
    PrivateTmp = true;
    ProtectHome = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
  };

  assertions = [
    {
      assertion = config.services.sanoid.enable;
      message = "Sanoid must remain enabled for automated ZFS snapshots.";
    }

    {
      assertion =
        let
          template = config.services.sanoid.templates.storage;
        in
        template.autosnap && template.autoprune;
      message = "The Sanoid storage template must enable both snapshot creation and pruning.";
    }

    {
      assertion =
        let
          datasets = config.services.sanoid.datasets;
          protectedDatasets = [
            "mediapool/media"
            "mediapool/root"
          ];
        in
        lib.all (name: lib.elem "storage" datasets.${name}.useTemplate or [ ]) protectedDatasets;
      message = "Protected ZFS datasets must use the Sanoid storage retention template.";
    }
  ];
}
