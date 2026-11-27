# Monitoring Tailscale subnet router

Prometheus on `r730xd` scrapes the node exporters on `navi` and `oryx` through their Tailscale service addresses.

- `navi`: `100.105.143.108:9100`
- `oryx`: `100.83.220.18:9100`

`r730xd` does not run a Tailscale client. Its traffic to the Tailnet is routed through the pfSense Tailscale subnet router.

## Required outbound NAT

The pfSense Tailscale subnet router must perform outbound NAT for traffic originating from the `192.168.1.0/24` LAN and leaving through its Tailscale interface.

In pfSense, configure this under **Firewall → NAT → Outbound**:

| Field | Value |
|---|---|
| Interface | Tailscale interface |
| Protocol | TCP |
| Source | `192.168.1.0/24` |
| Destination | `100.64.0.0/10` |
| Destination port | `9100` |
| Translation address | Interface Address |

The translation address must be the pfSense Tailscale interface address (its `100.x.x.x` Tailnet address), not its WAN address.

Without this NAT rule, the TCP handshake can fail asymmetrically: `navi` or `oryx` receives the SYN and sends a SYN-ACK through `tailscale0`, but the return traffic does not complete the connection. Prometheus then reports the target as down with a `context deadline exceeded` error.

## Network isolation

Do not use the `192.168.2.x` LAN addresses for Prometheus scraping.

The `192.168.1.0/24` and `192.168.2.0/24` networks are intentionally isolated. The monitoring path is:

```text
r730xd (192.168.1.2)
  -> pfSense Tailscale subnet router
  -> Tailscale
  -> navi or oryx node exporter
```

The desktop firewall rules allow the Prometheus host, `192.168.1.2`, to reach TCP port `9100`.

## Validation

From `r730xd`, inspect the active Prometheus node targets:

```sh
curl -fsS 'http://192.168.1.2:9090/api/v1/targets?state=active' \
  | jq -r '.data.activeTargets[]
      | select(.labels.job == "node")
      | [.labels.instance, .health, .lastError, .scrapeUrl]
      | @tsv'
```

All five `node` targets should report `up`.

To test an individual desktop exporter:

```sh
curl -v --max-time 5 http://100.105.143.108:9100/metrics -o /dev/null
curl -v --max-time 5 http://100.83.220.18:9100/metrics -o /dev/null
```

## Alerting

The existing `NodeDown` alert fires when a `node` scrape target remains unavailable for five minutes:

```yaml
expr: up{job="node"} == 0
for: 5m
```

If `navi` or `oryx` becomes unavailable, first check the pfSense outbound NAT rule and the Tailscale subnet-router return path before changing the NixOS firewall or node-exporter configuration.
