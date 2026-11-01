# Recovery runbook

This runbook covers recovery for the NixOS fleet. It assumes the repository is
available, at least one host can boot the NixOS installer, and SOPS age
identities are recoverable.

## Recovery order

1. Restore network access and DNS.
2. Rebuild or redeploy the affected host.
3. Restore persistent service data.
4. Verify monitoring, PostgreSQL, Synapse, and MatrixRTC.
5. Resume normal backups and certificate-renewal automation.

## Rebuild a NixOS host

From a machine with the repository and a reachable target host:

```bash
git clone https://github.com/aljam/nixlab.git
cd nixlab
nixos-rebuild switch --flake .#<host> --target-host root@<host>
```

For a host that cannot boot normally, boot the NixOS installer, mount its
filesystems, then use `nixos-install --flake .#<host>` with the appropriate
mount points and hardware configuration.

## SOPS recovery

SOPS secrets are encrypted to host age keys derived from the host SSH keys and
to the configured user age identities.

1. Recover the relevant age identity file or host SSH private key.
2. Confirm the recipient appears in `.sops.yaml`.
3. Decrypt a known-good secret to verify access:

   ```bash
   sops -d secrets/common.yaml >/dev/null
   ```

4. If a host SSH key was replaced, re-encrypt affected secret files to the
   new host age recipient before rebuilding that host.

## PostgreSQL recovery

PostgreSQL runs on `r820`. Restore from a consistent `pg_dump` archive, not
from a live data directory.

```bash
# Stop the dependent service first if restoring its database.
sudo systemctl stop matrix-synapse

# Restore a database from a custom-format dump.
sudo -u postgres pg_restore \
  --dbname=matrix-synapse \
  --clean \
  --if-exists \
  /path/to/matrix-synapse.dump

sudo systemctl start matrix-synapse
```

After restoring, verify TLS connectivity from `r730xd`:

```bash
psql \
  "host=r820.derezzed.info port=5432 dbname=matrix-synapse user=matrix-synapse sslmode=verify-full" \
  -c 'select 1;'
```

## Synapse recovery

Synapse runs on `r730xd` and uses PostgreSQL on `r820`.

1. Restore the Synapse configuration and media store from backup.
2. Ensure the PostgreSQL `matrix-synapse` database and role are available.
3. Ensure the SOPS-managed database configuration decrypts successfully.
4. Start Synapse and inspect logs:

   ```bash
   sudo systemctl restart matrix-synapse
   sudo journalctl -u matrix-synapse -f
   ```

5. Verify federation and client login through the normal Matrix endpoints.

## MatrixRTC recovery

MatrixRTC uses LiveKit and `lk-jwt-service` as Podman-backed systemd services.

```bash
sudo systemctl restart podman-livekit.service podman-lk-jwt-service.service
sudo journalctl -u podman-livekit.service -u podman-lk-jwt-service.service -f
```

Verify that the JWT service and LiveKit SFU are reachable through the pfSense
HAProxy backend, then place a test MatrixRTC call.

## Vaultwarden recovery

Restore the Vaultwarden data directory and database state from backup, then:

```bash
sudo systemctl restart vaultwarden
sudo journalctl -u vaultwarden -f
```

Verify login, unlock behavior, and attachment access before declaring recovery
complete.

## PostgreSQL certificate replacement

PostgreSQL expects the server certificate and unencrypted key at:

```text
/var/lib/postgresql/ssl/server.crt
/var/lib/postgresql/ssl/server.key
```

Use the repository renewal script or install the files manually:

```bash
sudo install -d -o postgres -g postgres -m 700 /var/lib/postgresql/ssl
sudo install -o postgres -g postgres -m 644 server.crt \
  /var/lib/postgresql/ssl/server.crt
sudo install -o postgres -g postgres -m 600 server.key \
  /var/lib/postgresql/ssl/server.key
sudo systemctl reload postgresql
```

Verify from `r730xd` with `sslmode=verify-full`, then confirm that the
Prometheus TLS certificate-expiry alert clears.

## Post-recovery verification

- `systemctl --failed` returns no unexpected failed units.
- Prometheus shows all node targets as up.
- The PostgreSQL TCP and TLS probes report `probe_success = 1`.
- Synapse can reach PostgreSQL and users can log in.
- MatrixRTC calls can connect through LiveKit.
- Vaultwarden unlocks and serves its configured data.
- Certificate renewal automation is configured and the next renewal date is
  visible in pfSense ACME.
