# Disk Health and Backup Assurance

## Disk Health

The disk-health exporter previously used `set -e`, so a single failing
`smartctl` check or a ZFS pool with data errors could abort the entire
export before the metrics file was published.

This change keeps the exporter running after individual device or pool
failures, records the appropriate unhealthy state, and publishes the
complete metrics file.

The initial refresh now occurs one minute after boot, with a 30-second
random delay, so Grafana receives data without waiting for the first
15-minute interval.

## Backup Assurance

Restic backup, verification, and restore-test jobs already write their
metrics to node_exporter's textfile directory at both job start and job
completion.

A job that has never run will not yet have a metric file. Trigger one job
manually to create its initial assurance metrics:

```bash
systemctl start restic-backup-<job>.service
```

Then verify:

```bash
curl -fsS http://127.0.0.1:9100/metrics | grep nixlab_restic_
```

## Validation

After rebuilding an affected host:

```bash
systemctl start disk-health-exporter.service
curl -fsS http://127.0.0.1:9100/metrics | grep disk_health_
```

Then confirm that Prometheus has a healthy `node` target for the host and
that the Disk Health and Backup Assurance dashboards render data.
