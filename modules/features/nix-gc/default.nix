{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.features.nix-gc;

  textfileDirectory = config.modules.features.node-exporter.textfileDirectory;

  wrapper = pkgs.writeShellScript "nixlab-gc" ''
    set -euo pipefail

    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.nix
        pkgs.util-linux
      ]
    }:$PATH"

    profile="/nix/var/nix/profiles/system"
    lock_dir="/run/nixlab-gc"
    lock_file="$lock_dir/nix-gc.lock"
    maintenance_dir="/run/nixlab-maintenance"
    metrics_dir="${textfileDirectory}"
    metrics_file="$metrics_dir/nix-gc.prom"
    metrics_tmp="$metrics_dir/.nix-gc.prom.$$"

    minimum_generations="${toString cfg.retention.generations}"
    retention_age="${cfg.retention.age}"

    started_at="$(date +%s)"
    previous_success=0

    install -d -m 0700 "$lock_dir"
    install -d -m 0755 "$metrics_dir"
    touch "$lock_file"
    chmod 0600 "$lock_file"
    exec 9>"$lock_file"

    if [[ -f "$metrics_file" ]]; then
      previous_success="$(
        sed -n 's/^nixlab_gc_last_success_timestamp_seconds //p' "$metrics_file" \
          | tail -n 1
      )"
    fi

    write_metrics() {
      local status="$1"
      local duration="$2"
      local last_success="$3"

      printf 'nixlab_gc_success %s\n' "$status" > "$metrics_tmp"
      printf 'nixlab_gc_duration_seconds %s\n' "$duration" >> "$metrics_tmp"
      printf 'nixlab_gc_last_success_timestamp_seconds %s\n' "$last_success" >> "$metrics_tmp"

      chmod 0644 "$metrics_tmp"
      mv -f "$metrics_tmp" "$metrics_file"
    }

    cleanup_failure() {
      local exit_code="$?"
      local finished_at
      finished_at="$(date +%s)"

      rm -f "$metrics_tmp"
      write_metrics 0 "$((finished_at - started_at))" "$previous_success"

      exit "$exit_code"
    }
    trap cleanup_failure ERR

    if ! flock -n 9; then
      echo "Another Nix garbage-collection run is already active." >&2
      exit 75
    fi

    for lock_name in deployment upgrade backup; do
      maintenance_lock="$maintenance_dir/$lock_name.lock"

      if [[ -e "$maintenance_lock" ]] && ! flock -n "$maintenance_lock" true; then
        echo "Deferring Nix garbage collection: $lock_name is active." >&2
        exit 75
      fi
    done

    if [[ ! -e "$profile" ]]; then
      echo "Nix system profile does not exist: $profile" >&2
      exit 1
    fi

    current_generation="$(readlink -f /run/current-system)"

    if [[ -z "$current_generation" ]]; then
      echo "Unable to determine the current Nix system generation." >&2
      exit 1
    fi

    mapfile -t generations < <(
      find /nix/var/nix/profiles -maxdepth 1 -type l \
        -name 'system-*-link' \
        -printf '%f\n' \
        | sed -E 's/^system-([0-9]+)-link$/\1/' \
        | sort -n
    )

    if (( ''${#generations[@]} == 0 )); then
      echo "No Nix system generations were found." >&2
      exit 1
    fi

    protected_count=0
    eligible_generations=()
    cutoff_time="$((started_at - $(date -d "-$retention_age" +%s)))"

    for (( index = ''${#generations[@]} - 1; index >= 0; index-- )); do
      generation="''${generations[index]}"
      generation_path="$(readlink -f "$profile-$generation-link" 2>/dev/null || true)"

      if [[ -z "$generation_path" ]]; then
        continue
      fi

      if [[ "$generation_path" == "$current_generation" ]]; then
        continue
      fi

      if (( protected_count < minimum_generations )); then
        protected_count=$((protected_count + 1))
        continue
      fi

      generation_mtime="$(stat -L -c %Y "$profile-$generation-link")"

      if (( generation_mtime <= cutoff_time )); then
        eligible_generations+=("$generation")
      fi
    done

    if (( ''${#eligible_generations[@]} == 0 )); then
      finished_at="$(date +%s)"
      trap - ERR
      write_metrics 1 "$((finished_at - started_at))" "$finished_at"
      echo "No generations are eligible for garbage collection."
      exit 0
    fi

    nix-env --profile "$profile" \
      --delete-generations "''${eligible_generations[@]}"

    remaining_generations="$(
      find /nix/var/nix/profiles -maxdepth 1 -type l \
        -name 'system-*-link' \
        -printf '%f\n' \
        | sed -E 's/^system-([0-9]+)-link$/\1/' \
        | sort -n \
        | wc -l
    )"

    if (( remaining_generations < minimum_generations )); then
      echo "Refusing to continue: only $remaining_generations generations remain." >&2
      exit 1
    fi

    current_after_gc="$(readlink -f /run/current-system)"

    if [[ "$current_after_gc" != "$current_generation" ]]; then
      echo "Refusing to continue: the current generation changed during GC." >&2
      exit 1
    fi

    finished_at="$(date +%s)"
    trap - ERR
    write_metrics 1 "$((finished_at - started_at))" "$finished_at"
  '';
in
{
  imports = [
    ../node-exporter.nix
  ];

  options.modules.features.nix-gc = {
    enable = lib.mkEnableOption "controlled Nix garbage collection";

    schedule = lib.mkOption {
      type = lib.types.str;
      example = "Sun 03:00";
      description = "Systemd calendar schedule for automatic garbage collection.";
    };

    retention = {
      generations = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
        description = "Minimum number of Nix generations to retain, including the current generation.";
      };

      age = lib.mkOption {
        type = lib.types.str;
        example = "14 days";
        description = "Minimum age of generations eligible for deletion.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.retention.generations >= 4;
        message = "modules.features.nix-gc.retention.generations must be at least 4.";
      }
      {
        assertion = cfg.retention.age != "";
        message = "modules.features.nix-gc.retention.age must be set.";
      }
    ];

    systemd.services.nixlab-nix-gc = {
      description = "NixLab controlled Nix garbage collection";
      wantedBy = [ "timers.target" ];
      after = [ "network.target" ];
      requires = [ "nix-daemon.socket" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${wrapper}";
        User = "root";
        Group = "root";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";

        ReadWritePaths = [
          textfileDirectory
          "/nix/var/nix"
        ];
      };
    };

    systemd.timers.nixlab-nix-gc = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "15min";
        Unit = "nixlab-nix-gc.service";
      };
    };
  };
}
