# Runbook

## Alert delivery test

Use the controlled test alerts to validate the Alertmanager-to-Ntfy delivery
path:

```console
nixlab-alert-test --severity warning
nixlab-alert-resolve --severity warning
```

For critical delivery validation:

```console
nixlab-alert-test --severity critical
nixlab-alert-resolve --severity critical
```

Test alerts use the `NixLabAlertDeliveryTest` alert name. Resolve every test
alert after validating delivery.

## System services

Check for failed services:

```console
systemctl --failed
systemctl --user --failed
```
