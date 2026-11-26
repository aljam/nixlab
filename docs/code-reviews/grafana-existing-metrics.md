# Grafana dashboard metric sources

## Problem

The Tailscale, Backup Assurance, and Disk Health dashboards show **No data** because their required metric-producing features are not enabled or configured on the scraped hosts. The prior health-exporter approach duplicated metrics already provided by existing modules.

## Existing metric producers

| Dashboard | Existing producer | Required configuration |
|---|---|---|
| Tailscale | `modules.features.tailscale-health` writes `nixlab_tailscale_*` through node_exporter. | Enable on hosts running Tailscale. |
| Disk Health | `modules.features.disk-health` writes SMART and ZFS metrics through node_exporter. | Enable and configure monitored devices; ZFS metrics require ZFS pools. |
| Backup Assurance | `modules.features.restic-backup` writes Restic result, timestamp, and duration metrics through node_exporter. | Enable and define at least one backup job. |
| Tailnet reachability | Prometheus Blackbox exporter writes `probe_success{network="tailscale"}`. | Configure `modules.features.prometheus-server.tailscaleServices`. |

## Correct integration

- node_exporter already enables the textfile collector and reads `/var/lib/node-exporter/textfile`.
- Prometheus already scrapes node_exporter on physical hosts through the `node` job.
- No additional exporter is needed for Tailscale, disk health, or Restic backup assurance.

## Host validation

After enabling the relevant modules and waiting for their timers, validate with:

```bash
curl -fsS http://127.0.0.1:9100/metrics | grep -E 'nixlab_tailscale_|disk_health_|nixlab_restic_'
```

For the Tailscale reachability panel, confirm Prometheus has an active `blackbox-tailscale` target. That job is only created when `tailscaleServices` is nonempty.

## Security

No new network listener, credentials, or privileged exporter is introduced. The existing node_exporter, Tailscale health, disk-health, and Restic backup modules retain their existing security boundaries.
