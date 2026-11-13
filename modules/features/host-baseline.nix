{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  textfileDirectory = config.modules.features.node-exporter.textfileDirectory;

  cfg = config.modules.features.host-baseline;

  systemctl = lib.getExe' pkgs.systemd "systemctl";
  journalctl = lib.getExe' pkgs.systemd "journalctl";
  ausearch = lib.getExe' pkgs.audit "ausearch";
  sshd = lib.getExe' pkgs.openssh "sshd";

  baselineScript = pkgs.writers.writeBash "nixlab-host-baseline" ''
    set -euo pipefail

    output="${textfileDirectory}/nixlab-host-baseline.prom"
    tmp="$output.tmp"

    failed_system_units="$(${systemctl} --failed --no-legend | wc -l)"
    failed_user_units="$(${systemctl} --user --failed --no-legend | wc -l)"
    journal_usage_bytes="$(${journalctl} --disk-usage | awk '{print $1}')"

    audit_records_recent=1
    if [ ! -d /var/lib/audit ] || [ -z "$(find /var/lib/audit -type f -mmin -1440 -print -quit)" ]; then
      audit_records_recent=0
    fi

    ssh_hardening_ok=1
    ssh_config="$(${sshd} -T 2>/dev/null || true)"
    if ! grep -q '^passwordauthentication no$' <<<"$ssh_config" \
      || ! grep -q '^kbdinteractiveauthentication no$' <<<"$ssh_config" \
      || ! grep -q '^permitrootlogin no$' <<<"$ssh_config"; then
      ssh_hardening_ok=0
    fi

    privileged_events="$(${ausearch} -k sudo-execution -ts recent 2>/dev/null | grep -c '^----' || true)"
    identity_events="$(${ausearch} -k identity-change -ts recent 2>/dev/null | grep -c '^----' || true)"

    cat > "$tmp" <<EOF
    # HELP nixlab_host_baseline_failed_system_units Number of failed system units.
    # TYPE nixlab_host_baseline_failed_system_units gauge
    nixlab_host_baseline_failed_system_units $failed_system_units

    # HELP nixlab_host_baseline_failed_user_units Number of failed user units.
    # TYPE nixlab_host_baseline_failed_user_units gauge
    nixlab_host_baseline_failed_user_units $failed_user_units

    # HELP nixlab_host_baseline_journal_usage_bytes Journal disk usage in bytes.
    # TYPE nixlab_host_baseline_journal_usage_bytes gauge
    nixlab_host_baseline_journal_usage_bytes $journal_usage_bytes

    # HELP nixlab_host_baseline_audit_records_recent Whether audit records are recent.
    # TYPE nixlab_host_baseline_audit_records_recent gauge
    nixlab_host_baseline_audit_records_recent $audit_records_recent

    # HELP nixlab_host_baseline_ssh_hardening_ok Whether SSH hardening is intact.
    # TYPE nixlab_host_baseline_ssh_hardening_ok gauge
    nixlab_host_baseline_ssh_hardening_ok $ssh_hardening_ok

    # HELP nixlab_host_baseline_privileged_events Recent privileged events.
    # TYPE nixlab_host_baseline_privileged_events gauge
    nixlab_host_baseline_privileged_events $privileged_events

    # HELP nixlab_host_baseline_identity_events Recent identity-change events.
    # TYPE nixlab_host_baseline_identity_events gauge
    nixlab_host_baseline_identity_events $identity_events
    EOF

    mv "$tmp" "$output"
  '';
in
{
  options.modules.features.host-baseline = {
    enable = mkEnableOption "host security baseline audit";

    journalUsageLimitBytes = mkOption {
      type = types.int;
      default = 1073741824;
      description = "Maximum journal disk usage in bytes before alerting.";
    };

    filesystemUsageThresholdPercent = mkOption {
      type = types.int;
      default = 85;
      description = "Filesystem usage percentage before alerting.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.nixlab-host-baseline = {
      description = "Collect host security baseline metrics";
      after = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = baselineScript;
        User = "node-exporter";
        Group = "node-exporter";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ textfileDirectory ];
        ProtectHome = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        LockPersonality = true;
      };
    };

    systemd.timers.nixlab-host-baseline = {
      description = "Collect host security baseline metrics every 15 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "15min";
        AccuracySec = "1min";
        Persistent = true;
      };
    };
  };
}
