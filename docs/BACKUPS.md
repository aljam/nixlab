# Backups

NixLab uses Restic for file and database backups, Sanoid for ZFS snapshots, and recovery procedures for restoring services.

## Backup layers

| Layer | Tool | Purpose |
|---|---|---|
| ZFS snapshots | Sanoid | Local point-in-time recovery and replication. |
| File and database backups | Restic | Off-host or remote backup of important data. |
| Service recovery | Recovery runbook | Restore service state after failure. |

## Routine checks

- Confirm backup jobs completed successfully.
- Confirm snapshots are current.
- Confirm backup storage has sufficient capacity.
- Test restoration periodically.
- Verify that critical databases and service state are included.

## Restoring data

For PostgreSQL, restore from a consistent `pg_dump` archive rather than a live data directory.

For service state, restore the relevant data directory and restart the service.

For full host recovery, follow [Recovery](RECOVERY.md).

## Before replacing hardware

Before replacing a disk or rebuilding a host:

1. Confirm backups are current.
2. Confirm ZFS pool redundancy.
3. Confirm the replacement hardware is compatible.
4. Preserve or rotate SOPS host keys as needed.
5. Follow [Secrets](SECRETS.md) for key and recipient changes.

## Verification

After restoration, use [Service health checks](RUNBOOK.md#service-health-checks) to verify systemd units, monitoring, PostgreSQL, Synapse, MatrixRTC, Vaultwarden, and certificate renewal.
