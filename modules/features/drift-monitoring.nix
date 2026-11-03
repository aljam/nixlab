# Runtime drift monitoring.
#
# Exports lightweight runtime signals through the node_exporter textfile
# collector:
#
# - Number of listening TCP and UDP sockets.
# - SHA-256 of the active nftables ruleset.
# - Active NixOS configuration revision.
#
# These metrics make unexpected listeners, out-of-band firewall edits, and
# untracked deployments visible to Prometheus without exposing any new network
# service.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  textfileDirectory = "/var/lib/node-exporter/textfile";

  driftScript = pkgs.writers.writeBash "nixlab-drift-metrics" ''
    set -euo pipefail

    output="${textfileDirectory}/nixlab-drift.prom"
    tmp="$output.tmp"

    mkdir -p "$(dirname "$tmp")"
    chmod 0750 "$(dirname "$tmp")"

    tcp_listeners="$(ss -Hltn | wc -l)"
    udp_listeners="$(ss -Hlun | wc -l)"
    ruleset_hash="$(nft list ruleset | sha256sum | cut -d' ' -f1)"
    revision="$(nixos-version --configuration-revision 2>/dev/null || true)"

    cat > "$tmp" <<EOF
    # HELP nixlab_listening_tcp_sockets Number of listening TCP sockets.
    # TYPE nixlab_listening_tcp_sockets gauge
    nixlab_listening_tcp_sockets $tcp_listeners

    # HELP nixlab_listening_udp_sockets Number of listening UDP sockets.
    # TYPE nixlab_listening_udp_sockets gauge
    nixlab_listening_udp_sockets $udp_listeners

    # HELP nixlab_nftables_ruleset_sha256 Active nftables ruleset identity.
    # TYPE nixlab_nftables_ruleset_sha256 gauge
    nixlab_nftables_ruleset_sha256{hash="$ruleset_hash"} 1

    # HELP nixlab_system_revision Active NixOS configuration revision.
    # TYPE nixlab_system_revision gauge
    nixlab_system_revision{revision="$revision"} 1
    EOF

    mv "$tmp" "$output"
  '';
in
{
  config = lib.mkIf config.services.prometheus.exporters.node.enable {
    services.prometheus.exporters.node = {
      enabledCollectors = [ "textfile" ];
      extraFlags = [
        "--collector.textfile.directory=${textfileDirectory}"
      ];
    };

    systemd.services.nixlab-drift-metrics = {
      description = "Collect NixOS runtime drift metrics";
      after = [ "network.target" "nftables.service" ];
      wants = [ "nftables.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${driftScript}";
        User = "node-exporter";
        Group = "node-exporter";

        StateDirectory = "nixlab-drift";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_NETLINK" ];
        LockPersonality = true;
      };
    };

    systemd.timers.nixlab-drift-metrics = {
      description = "Collect NixOS runtime drift metrics every five minutes";
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
