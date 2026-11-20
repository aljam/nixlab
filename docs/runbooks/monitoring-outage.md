# Monitoring outage response

Use this runbook when Prometheus, Alertmanager, ntfy, Loki, Grafana, or drift monitoring is unavailable or unreliable.

A monitoring outage is itself an operational incident. Do not treat the absence of alerts, an empty dashboard, or missing logs as evidence that workloads are healthy.

## Scope

Use this runbook for:

- Prometheus is not scraping targets, evaluating rules, or retaining recent metrics.
- Alertmanager is not grouping, routing, repeating, or resolving alerts.
- ntfy is not delivering warning, critical, or recovery notifications.
- Loki is not ingesting, storing, or serving logs.
- Grafana is unavailable or cannot query required data sources.
- Drift monitoring is not detecting configuration or service changes.

Use service-specific recovery procedures for a workload failure that has an identified cause and does not primarily involve the monitoring control plane.

## Initial response

1. Declare an incident using `docs/runbooks/incident-severity.md`.
2. Identify the failed component, affected host, failure time, and suspected scope.
3. Determine whether the outage affects one component or the monitoring control plane.
4. Determine whether critical workloads can still be assessed through direct, independent checks.
5. Assign owners for containment, recovery, verification, and incident records.

Do not make destructive changes based solely on incomplete monitoring data. Absence of an alert is not evidence that a service is healthy.

## Preserve evidence

Before restarting or changing configuration, retain:

- System journal entries for the affected monitoring services.
- Service status, recent restarts, and failed-unit information.
- Prometheus target, rule-evaluation, and alert-state information where available.
- Alertmanager notification and routing logs.
- ntfy delivery or relay logs.
- Loki ingestion, retention, and query errors.
- Grafana data-source and authentication errors.
- Drift-monitoring results and configuration-change records.

Record the collection time, host, collector or command, and storage location for each artifact.

## Contain the outage

1. Avoid broad restarts or configuration changes until the failed component is identified.
2. Use direct checks for critical services when monitoring is unavailable.
3. Prevent cascading recovery actions that could obscure the original failure.
4. If Alertmanager or ntfy is unavailable, establish an interim operator communication channel.
5. If Prometheus is unavailable, treat workload alerts as unverified until metrics collection and rule evaluation are restored.
6. If Loki is unavailable, preserve local logs where possible before restarting or clearing log state.

## Recover components

Recover dependencies before dependent components:

1. Restore the underlying host, network path, storage, and service dependencies.
2. Restore Prometheus so metrics collection and alert evaluation resume.
3. Restore Alertmanager so alerts can be grouped, routed, repeated, and resolved.
4. Restore ntfy so notifications reach operators.
5. Restore Loki so logs can be ingested and queried.
6. Restore Grafana and drift monitoring after their data sources and dependencies are available.

Restart only the affected service after reviewing its logs and configuration. Do not disable alerts, delete data, or bypass notification routing as a recovery shortcut.

## Verify observability

Before closing the incident, verify:

- Prometheus is scraping the expected targets and evaluating alert rules.
- Alertmanager is receiving, grouping, routing, repeating, and resolving alerts.
- ntfy delivers notifications to the intended operator channel.
- Loki is ingesting logs and supports queries for the affected period where retention permits.
- Grafana can query its data sources and render required dashboards.
- Drift monitoring is running and can detect configuration or service changes.
- Critical workloads are healthy using direct checks as well as monitoring data.

Run the controlled alert-delivery validation after restoring Alertmanager and ntfy:

```console
nixlab-alert-test --severity warning
nixlab-alert-resolve --severity warning
```

Use only the `NixLabAlertDeliveryTest` alert name for this validation. Do not use test alerts to validate a production incident.

## Backfill and review

1. Identify the outage window and any monitoring data that was lost or delayed.
2. Review whether an alert, log query, dashboard, or external signal could have detected the outage earlier.
3. Determine whether critical workloads experienced an unobserved failure during the outage.
4. Record the incident timeline, affected components, recovery actions, verification results, and retained evidence.
5. Create follow-up work for resilience, independent availability signals, alert coverage, or documentation gaps.

Do not assume that monitoring recovery proves workload health. Verify both the monitoring control plane and the workloads it observes.

## Related documentation

- `docs/runbooks/incident-severity.md`
- `docs/MONITORING.md`
- `docs/audits/alert-delivery.md`
- `docs/audits/incident-response-recovery.md`
- `docs/runbooks/host-compromise-recovery.md`
