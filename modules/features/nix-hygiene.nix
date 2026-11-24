{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.features.nix-hygiene;
  metricsDirectory = config.modules.features.node-exporter.textfileDirectory;
  metricsScript = pkgs.writeShellScript "nix-hygiene-metrics" ''
    set -eu
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT

    store_size="$(du -sb /nix/store | awk '{print $1}')"
    gc_timestamp="$(systemctl show nix-gc.service -p ExecMainExitTimestampMonotonic --value 2>/dev/null || echo 0)"

    cat >"$tmp" <<EOF
    nixlab_nix_store_size_bytes $store_size
    nixlab_nix_gc_last_success_timestamp_seconds $gc_timestamp
    EOF

    install -m 0640 "$tmp" "${metricsDirectory}/nix-hygiene.prom"
  '';
in
{
  options.modules.features.nix-hygiene = {
    enable = lib.mkEnableOption "Nix store hygiene maintenance and observability";

    optimise.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run a monthly Nix store optimisation job.";
    };

    gcRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Minimum age of Nix generations retained by garbage collection.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than ${toString cfg.gcRetentionDays}d";
      randomizedDelaySec = "45min";
    };

    systemd.services.nix-hygiene-metrics = {
      description = "Publish Nix store hygiene metrics";
      after = [ "nix-gc.service" ];
      wants = [ "nix-gc.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = metricsScript;
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.nix-hygiene-metrics = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "15min";
        Persistent = true;
      };
    };

    systemd.services.nix-store-optimise = lib.mkIf cfg.optimise.enable {
      description = "Optimize the Nix store";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.nix}/bin/nix store optimise";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.nix-store-optimise = lib.mkIf cfg.optimise.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
    };

    assertions = [
      {
        assertion = cfg.gcRetentionDays >= 7;
        message = "Nix garbage collection must retain generations for at least seven days.";
      }
    ];
  };
}
