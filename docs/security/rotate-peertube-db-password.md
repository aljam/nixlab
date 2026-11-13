# Rotate the PeerTube database password

This runbook rotates the SOPS-managed password for the PeerTube PostgreSQL
role after its prior plaintext exposure.

Do not commit, paste, log, or otherwise retain the generated password.

## Prerequisites

Run these steps on `r820` from a current checkout of `nixlab`.

```bash
cd ~/nixlab
git pull
```

Confirm the SOPS secret path and key name before editing it:

```bash
sops --decrypt secrets/peertube-db-password.yaml | jq 'keys'
```

Adjust the path and key name in the following commands if they differ.

## Generate a password

Generate a strong password in a shell variable. Do not echo it or save it to
a file.

```bash
new_password=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c 40)
```

## Update the SOPS secret

Update the encrypted secret:

```bash
sops --set '["peertube-db-password"]' "$new_password" \
  secrets/peertube-db-password.yaml
```

Deploy the updated secret:

```bash
sudo nixos-rebuild switch --flake .#r820
```

## Update PostgreSQL

Update the existing PostgreSQL role before restarting PeerTube:

```bash
sudo -u postgres psql -d postgres <<SQL
ALTER ROLE peertube PASSWORD '$new_password';
SQL
```

## Restart and verify

Restart PeerTube and inspect its logs:

```bash
sudo systemctl restart peertube
sudo systemctl status peertube --no-pager
journalctl -u peertube.service -n 100 --no-pager
```

Verify that PeerTube can authenticate over TLS:

```bash
PGPASSWORD="$(sudo cat /run/secrets/peertube-db-password)" \
  psql "host=192.168.1.4 port=5432 dbname=peertube user=peertube sslmode=require" \
  -c 'select 1;'
```

A successful `select 1` confirms that the rotated password works and that the
connection uses TLS.

## Clean up

Remove the password from the current shell environment and history:

```bash
unset new_password
history -c
```

The password must remain encrypted in SOPS and should only be surfaced through
`/run/secrets/peertube-db-password`.
