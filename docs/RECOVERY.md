# Recovery

## SOPS recovery

Before deploying a rebuilt or replaced host:

1. Generate a new age recipient for the host.
2. Update `.sops.yaml` with the new recipient.
3. Remove the retired host recipient.
4. Re-encrypt every secret authorized for that host.
5. Run the SOPS recovery drill:

```console
nix flake check --show-trace
nix run .#vm -- --run sops-recovery
```

6. Confirm the host can decrypt only its authorized secrets.
7. Deploy the host only after the drill passes.

## PostgreSQL recovery

After restoring PostgreSQL, reload the service:

```console
sudo systemctl reload postgresql
```

Verify from `r730xd` with `sslmode=verify-full`, then confirm that the
Prometheus TLS certificate-expiry alert clears.

## Post-recovery verification

Check Prometheus and Alertmanager for active or pending alerts. Important
signals include node-exporter targets, filesystem capacity, failed units,
memory pressure, PostgreSQL TCP reachability, and PostgreSQL TLS certificate
expiry.
