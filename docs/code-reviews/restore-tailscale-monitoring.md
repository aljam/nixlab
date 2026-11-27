# Code review: restore Tailscale monitoring

## Goal

Restore Tailscale health visibility for `navi` and `oryx` now that the pfSense NAT/firewall routing path is working.

## Current state

- The prior `modules.features.tailscale-health` implementation was removed because its metrics were not being produced or scraped reliably.
- `navi` and `oryx` are direct Tailscale clients and should be monitored individually.
- Servers use subnet-level Tailscale through pfSense; they should not receive a duplicate desktop exporter.
- Prometheus on `r730xd` already scrapes the node exporters on `navi` at `100.105.143.108:9100` and `oryx` at `100.83.220.18:9100`.

## Intended change

1. Restore a minimal `modules/features/tailscale-health.nix` module.
2. Use Tailscale client metrics written through the existing node-exporter textfile collector, rather than adding another network-facing exporter service.
3. Enable the module only on `navi` and `oryx`.
4. Restore Prometheus scrape coverage through the existing node-exporter targets.
5. Restore the Tailscale dashboard panels for availability, last-seen age, authentication expiry, and update availability.
6. Add one conservative alert for a desktop host whose Tailscale health is stale or unavailable.
7. Add a VM test that verifies the textfile metrics, Prometheus scrape configuration, dashboard provisioning, and alert rule.

## Security review

- No new inbound service is exposed.
- Metrics remain local to each desktop host and are collected by the existing Prometheus scrape path.
- The module must not embed Tailscale API credentials or create a new privileged service.
- File permissions for generated metrics must remain readable by the node exporter but not world-writable.

## Operational review

- The implementation must be independently revertable without affecting backups, deployment, or desktop configuration.
- The dashboard should distinguish a missing metric from an unhealthy Tailscale state.
- Alerts must use conservative thresholds to avoid noise while a desktop is offline or asleep.

## Validation

```bash
nix build .#checks.x86_64-linux.tailscale-health
nix flake check
```

After deployment, verify that both `navi` and `oryx` populate the restored Tailscale dashboard.
