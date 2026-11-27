# Tailscale health

## Trigger

- `TailscaleHealthDegraded`: `tailscaled_health_messages > 0` for five minutes.

## Immediate checks

1. Confirm the affected host and health-condition type from the alert labels.
2. Run `tailscale status` on the affected host and look for errors or degraded state.
3. Inspect daemon logs: `journalctl -u tailscaled -n 200 --no-pager`.
4. Inspect the exported metrics: `cat /var/lib/node-exporter/textfile/tailscale.prom`.
5. Check whether the host can reach the Tailscale control plane and DERP relays.

## Common causes

- Expired or revoked node authorization.
- DNS or outbound-network failures preventing control-plane connectivity.
- `tailscaled` crash, restart loop, or systemd unit failure.
- Clock skew causing certificate or authentication failures.
- Subnet-router route approval pending or revoked.

## Remediation

1. Restart the client: `systemctl restart tailscaled`.
2. Re-run `tailscale status`; if the node is logged out, re-authenticate it.
3. If subnet routes are involved, confirm the routes are advertised and approved in the Tailscale admin console.
4. If the condition persists after restart and re-authentication, capture logs and metrics before further changes.

## Escalation

Escalate if the node remains unhealthy after a restart and re-authentication, if multiple nodes report the same condition, or if control-plane connectivity cannot be restored.

## Prevention

- Keep Tailscale and its systemd unit configuration current.
- Monitor the exported health metrics and investigate recurring conditions rather than repeatedly restarting.
- Maintain an inventory of subnet routes and their approval state.
