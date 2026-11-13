# Alert delivery validation

## Status

Implemented.

## Controls

- Submit controlled warning and critical test alerts to local Alertmanager.
- Validate that Alertmanager routes alerts to Ntfy.
- Validate that resolving a test alert produces a recovery notification.
- Validate warning and critical grouping and repeat intervals.
- Keep test alerts clearly labeled and scoped to the local Alertmanager endpoint.

## Validation

Build and run the NixOS VM test:

```console
nix build .#checks.x86_64-linux.alert-delivery
./result/bin/nixos-test-driver
```

For a manual production test from `r730xd`:

```console
nixlab-alert-test --severity warning
nixlab-alert-resolve --severity warning
```

Test alerts use the `NixLabAlertDeliveryTest` alert name and must not be used
to validate production incidents.
