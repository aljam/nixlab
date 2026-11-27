{
  pkgs,
}:
let
  dashboardFile = ../modules/features/grafana/dashboards/tailscale.json;
  rulesFile = ../modules/features/prometheus/rules/tailscale-rules.yml;
in
pkgs.runCommand "tailscale-observability-config-check"
  {
    inherit dashboardFile rulesFile;
  }
  ''
    ${pkgs.jq}/bin/jq -e '.uid == "nixlab-tailscale-health" and .title == "Tailscale Health"' "$dashboardFile" >/dev/null

    grep -q 'TailscaleHealthDegraded' "$rulesFile" || {
      echo "Tailscale rules are missing alert: TailscaleHealthDegraded" >&2
      exit 1
    }

    grep -q 'tailscaled_health_messages' "$rulesFile" || {
      echo "Tailscale rules are missing metric: tailscaled_health_messages" >&2
      exit 1
    }

    for metric in tailscaled_health_messages tailscaled_inbound_bytes_total tailscaled_outbound_bytes_total tailscaled_inbound_dropped_packets_total tailscaled_outbound_dropped_packets_total tailscaled_advertised_routes tailscaled_approved_routes tailscaled_home_derp_region_id; do
      grep -q "$metric" "$dashboardFile" || {
        echo "Tailscale dashboard is missing metric: $metric" >&2
        exit 1
      }
    done

    touch $out
  ''
