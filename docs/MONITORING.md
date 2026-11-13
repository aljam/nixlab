# Monitoring

NixLab uses Prometheus, Grafana, Alertmanager, node_exporter, Loki, and drift
monitoring for fleet observability.

## Alert delivery

Controlled alert delivery tests validate that Alertmanager routes warning and
critical alerts to Ntfy and that recovery notifications are delivered.

See [`docs/audits/alert-delivery.md`](audits/alert-delivery.md).

## Components

- Prometheus collects metrics and evaluates alert rules.
- Alertmanager groups, repeats, and routes alerts.
- Ntfy delivers notifications.
- node_exporter exposes host metrics.
- Loki collects logs.
- Drift monitoring detects configuration and service drift.
