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

  cfg = config.modules.features.drift-monitoring;

  expectedRevision = cfg.expectedRevision;
  expectedFirewallHash = cfg.expectedFirewallHash;
  criticalUnits = cfg.criticalUnits;
  allowedTcpPorts = cfg.allowedTcpPorts;
  allowedUdpPorts = cfg.allowedUdpPorts;

  ss = lib.getExe' pkgs.iproute2 "ss";
  nft = lib.getExe' pkgs.nftables "nft";
  systemctl = lib.getExe' pkgs.systemd "systemctl";

  tcpAllowList = lib.concatStringsSep "\n" (map toString allowedTcpPorts);
  udpAllowList = lib.concatStringsSep "\n" (map toString allowedUdpPorts);

  driftScript = pkgs.writers.writeBash "nixlab-drift-metrics" ''
    set -euo pipefail

    output="${textfileDirectory}/nixlab-drift.prom"
    tmp="$output.tmp"

    revision="$(/run/current-system/sw/bin/nixos-version --configuration-revision || true)"
    ruleset_hash="$(${nft} list ruleset | sha256sum | cut -d' ' -f1)"

    tcp_allow_list="${tcpAllowList}"
    udp_allow_list="${udpAllowList}"

    failed_units=0
    while IFS= read -r unit; do
      [ -z "$unit" ] && continue
      if ! ${systemctl} is-active --quiet "$unit"; then
        failed_units=$((failed_units + 1))
        printf 'nixlab_drift_failed_critical_unit{unit="%s"} 1\n' "$unit" >> "$tmp"
      fi
    done < <(printf '%s\n' "${lib.concatStringsSep "\n" criticalUnits}")

    unexpected_tcp=0
    while read -r port; do
      [ -z "$port" ] && continue
      if ! printf '%s\n' "$tcp_allow_list" | grep -Fxq "$port"; then
        unexpected_tcp=$((unexpected_tcp + 1))
        printf 'nixlab_drift_unexpected_listener{protocol="tcp",port="%s"} 1\n' "$port" >> "$tmp"
      fi
    done < <(${ss} -Hltn | awk '{print $4}' | awk -F: '{print $NF}' | sort -u)

    unexpected_udp=0
    while read -r port; do
      [ -z "$port" ] && continue
      if ! printf '%s\n' "$udp_allow_list" | grep -Fxq "$port"; then
        unexpected_udp=$((unexpected_udp + 1))
        printf 'nixlab_drift_unexpected_listener{protocol="udp",port="%s"} 1\n' "$port" >> "$tmp"
      fi
    done < <(${ss} -Hlun | awk '{print $4}' | awk -F: '{print $NF}' | sort -u)

    revision_mismatch=0
    if [ -n "$expected_revision" ] && [ "$revision" != "$expected_revision" ]; then
      revision_mismatch=1
    fi

    firewall_changed=0
    if [ -n "$expected_firewall_hash" ] && [ "$ruleset_hash" != "$expected_firewall_hash" ]; then
      firewall_changed=1
    fi

    cat > "$tmp" <<EOF
    # HELP nixlab_drift_revision_mismatch Active revision differs from expected revision.
    # TYPE nixlab_drift_revision_mismatch gauge
    nixlab_drift_revision_mismatch $revision_mismatch

    # HELP nixlab_drift_failed_critical_units Number of failed critical systemd units.
    # TYPE nixlab_drift_failed_critical_units gauge
    nixlab_drift_failed_critical_units $failed_units

    # HELP nixlab_drift_unexpected_listeners Number of undeclared listening sockets.
    # TYPE nixlab_drift_unexpected_listeners gauge
    nixlab_drift_unexpected_listeners $((unexpected_tcp + unexpected_udp))

    # HELP nixlab_drift_firewall_changed Active nftables ruleset differs from expected ruleset.
    # TYPE nixlab_drift_firewall_changed gauge
    nixlab_drift_firewall_changed $firewall_changed

    # HELP nixlab_system_revision Active NixOS configuration revision.
    # TYPE nixlab_system_revision gauge
    nixlab_system_revision{revision="$revision"} 1

    # HELP nixlab_nftables_ruleset_sha256 Active nftables ruleset identity.
    # TYPE nixlab_nftables_ruleset_sha256 gauge
    nixlab_nftables_ruleset_sha256{hash="$ruleset_hash"} 1
    EOF

    mv "$tmp" "$output"
  '';
in
{
  options.modules.features.drift-monitoring = {
    enable = mkEnableOption "configuration and service drift detection";

    expectedRevision = mkOption {
      type = types.str;
      default = "";
      description = "Expected NixOS configuration revision. Empty disables revision comparison.";
    };

    expectedFirewallHash = mkOption {
      type = types.str;
      default = "";
      description = "Expected SHA-256 hash of the active nftables ruleset. Empty disables firewall comparison.";
    };

    criticalUnits = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Systemd units that must remain active.";
    };

    allowedTcpPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = "TCP ports permitted to have listening sockets.";
    };

    allowedUdpPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      description = "UDP ports permitted to have listening sockets.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.nixlab-drift-metrics = {
      description = "Collect NixOS configuration and service drift metrics";
      after = [
        "network.target"
        "nftables.service"
      ];
      wants = [ "nftables.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = driftScript;
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
        AmbientCapabilities = [ "CAP_NET_ADMIN" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        LockPersonality = true;
      };
    };

    systemd.timers.nixlab-drift-metrics = {
      description = "Collect NixOS configuration and service drift metrics every five minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        AccuracySec = "30s";
        Persistent = true;
      };
    };
  };
}
