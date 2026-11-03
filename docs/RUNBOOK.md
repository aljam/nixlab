# Operational runbook

This runbook maps the principal Prometheus alerts to initial diagnostics and recovery actions.

## Security posture dashboard

The **Security posture** Grafana dashboard provides a fleet-wide view of:

- Node exporter availability.
- Failed systemd units.
- Listening TCP and UDP sockets.
- Matrix and RTC probe health.
- PostgreSQL probe health.

Use it as the first stop when investigating a host-health, drift, Matrix, or PostgreSQL alert.

## Host alerts

### NodeDown

**Meaning:** Prometheus cannot scrape a host’s node exporter.

1. Confirm the host is reachable over the management network.
2. Check `systemctl status prometheus-node-exporter` on the affected host.
3. Confirm the Prometheus server IP is still allowed by that host’s firewall.
4. Inspect `nft list ruleset` for unexpected firewall changes.

### SystemdUnitFailed

**Meaning:** One or more systemd units are in the failed state.

1. Identify the unit from the alert’s `name` label.
2. Run `systemctl status <unit>` and `journalctl -u <unit> -b`.
3. Repair or roll back the relevant NixOS configuration.
4. Confirm the unit is active after redeployment.

## Drift alerts

### ListeningTCPSocketsIncreased

**Meaning:** A host has more listening TCP sockets than it did one hour earlier.

1. Open the Security posture dashboard and identify the affected host.
2. Run `ss -Hltnp` on that host.
3. Compare new listeners with the expected services in NixOS configuration.
4. If the listener is unexpected, stop the service, inspect its unit and logs, and redeploy the declared configuration.

### NftablesRulesetDrift

**Meaning:** The active nftables ruleset hash changed.

1. Run `nft list ruleset` on the affected host.
2. Compare the rules with the latest NixOS deployment.
3. If the change was intentional, redeploy or wait for the alert to resolve.
4. If it was not intentional, redeploy the host and investigate how the ruleset changed.

## Matrix alerts

### MatrixClientAPIUnreachable

**Meaning:** The public Matrix client API did not return HTTP 200.

1. Check the Matrix Synapse service and its logs.
2. Confirm the HAProxy frontend and backend are healthy.
3. Probe `https://matrix.derezzed.info/_matrix/client/versions` from outside the LAN.
4. Check PostgreSQL connectivity if Synapse is failing to serve requests.

### MatrixFederationAPIUnreachable

**Meaning:** The Matrix server-key endpoint did not return HTTP 200.

1. Check Synapse and HAProxy logs.
2. Confirm the federation endpoint is intentionally exposed.
3. Verify TLS certificate validity and HAProxy frontend health.

### MatrixRTCUnreachable

**Meaning:** The RTC frontend did not return HTTP 200.

1. Check the LiveKit and JWT-service containers.
2. Confirm the RTC HAProxy frontend and backend are healthy.
3. Inspect `journalctl -u podman-livekit` and `journalctl -u podman-lk-jwt-service`, or the equivalent container runtime logs.
4. Verify the LiveKit secret and RTC configuration if containers restart repeatedly.

## PostgreSQL alerts

### PostgreSQLUnreachable

**Meaning:** The local TCP probe cannot reach PostgreSQL.

1. Check `systemctl status postgresql` on the database host.
2. Confirm PostgreSQL is listening on the expected loopback or fleet address.
3. Check the Blackbox exporter and its probe configuration.
4. Review firewall rules for changes affecting the Prometheus server.

### PostgreSQLTLSVerificationFailed

**Meaning:** The TLS PostgreSQL probe cannot verify the database certificate.

1. Check certificate expiry and renewal logs.
2. Confirm the CA bundle configured for the TLS probe is current.
3. Test the database TLS endpoint from the Prometheus host.
4. Redeploy the database or monitoring configuration after correcting the certificate or CA path.
