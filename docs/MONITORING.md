# Monitoring

NixLab uses Prometheus, Grafana, Alertmanager, node_exporter, Loki, and drift monitoring for fleet observability.

## Components

- Prometheus collects metrics and evaluates alert rules.
- Grafana provides dashboards and operational visibility.
- Alertmanager routes and groups alerts.
- node_exporter exposes host metrics.
- Loki and log-agent collect logs.
- Drift monitoring detects configuration drift.

## Routine checks

Use the shared [Service health checks](RUNBOOK.md#service-health-checks) for routine checks and incident triage.

## Important alerts

| Alert | First response |
|---|---|
| Node exporter target down | Verify the host is reachable, the exporter service is active, and firewall rules allow Prometheus access. |
| Filesystem capacity | Check usage with `df -h`, identify growth, and clean or expand storage as needed. |
| Failed systemd units | Inspect `systemctl --failed` and service logs. |
| PostgreSQL TCP reachability | Verify network, firewall, PostgreSQL service, and TLS configuration. |
| PostgreSQL certificate expiry | Renew or replace the certificate, reload PostgreSQL, and verify TLS connectivity. |
| Disk health | See [Disk health](DISK-HEALTH.md). |

## Adding monitoring

1. Enable or configure the relevant exporter or log agent.
2. Add scrape or log-ingest configuration where required.
3. Add or update alert rules.
4. Add or update a Grafana dashboard if useful.
5. Run `nix flake check`.
6. Deploy the affected host and verify targets and alerts.

## Alert hygiene

- Keep alerts actionable.
- Avoid duplicate alerts for the same failure mode.
- Include a first-response action in the alert annotation or runbook.
- Review alert thresholds during maintenance.
