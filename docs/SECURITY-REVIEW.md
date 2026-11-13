# Security review checklist

Use this checklist for a quarterly, dry-run security review. It complements
automated CI, policy assertions, monitoring, and recovery drills; it does not
replace them.

Keep the review simple: record what was checked, what was found, and the
decision made. Do not treat every scanner finding as an incident.

## 5. Monitoring and alerting

- [ ] Review active and pending Prometheus alerts.
- [ ] Confirm Alertmanager remains loopback-only.
- [ ] Send a test alert and confirm Ntfy delivery.
- [ ] Confirm warning and critical alerts are grouped and repeat appropriately.
- [ ] Confirm recovery notifications are delivered.

Use `nixlab-alert-test` and `nixlab-alert-resolve` for controlled delivery
validation. See [`docs/audits/alert-delivery.md`](audits/alert-delivery.md).
