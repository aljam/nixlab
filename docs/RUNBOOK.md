# Runbook

This page covers routine operational checks and first-response actions.

## Service health checks

After a deployment, recovery, or alert, verify the affected host:

```bash
systemctl --failed
systemctl --user --failed
```

Check Prometheus and Alertmanager for active or pending alerts. Important signals include node-exporter targets, filesystem capacity, failed units, memory pressure, PostgreSQL TCP reachability, and PostgreSQL TLS certificate expiry.

For PostgreSQL on `r820`, verify that the database is listening and the TLS certificate probe remains healthy.

For the media host, verify Servarr services and that new files under `/mnt/media` retain the shared `media` group ownership.

Use this section as the shared health-check reference for [Maintenance](MAINTENANCE.md), [Updates](UPDATES.md), and [Recovery](RECOVERY.md).

## Disk health

For SMART device checks, alert responses, and non-destructive tests, see [Disk health](DISK-HEALTH.md).