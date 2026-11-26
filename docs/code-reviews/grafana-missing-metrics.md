# Grafana missing metrics

## Problem

The Tailscale, Backup Assurance, and Disk Health dashboards display **No data** because they query custom metrics that are not produced anywhere in the repository:

- `nixlab_tailscale_*`
- `disk_health_*`
- `nixlab_restic_*`

Grafana itself is configured correctly: its Prometheus datasource uses UID `prometheus`, matching the dashboards.

## Intended change

Add one small local exporter that emits the metric families already expected by the dashboards. This avoids changing dashboard queries or introducing substitute metrics.

## Scope

- Add `modules/features/health-exporter.nix`.
- Expose metrics on a localhost-only HTTP endpoint by default.
- Add a Prometheus scrape job for the exporter.
- Keep dashboard JSON unchanged.
- Add a test that asserts the expected metric names are served.

## Security

- The exporter must not expose Tailscale auth keys, Restic credentials, or SOPS secrets.
- Bind only to the services bind address or loopback, never `0.0.0.0`.
- Use fixed command arguments and avoid interpolating untrusted values into shell commands.
- Restrict exporter access to the Prometheus host through the existing firewall policy.

## Follow-up

After merging, verify each dashboard panel returns data after the exporter has completed at least one collection interval.
