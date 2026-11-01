#!/usr/bin/env bash
# Deploy a renewed PostgreSQL certificate from pfSense to r820.
#
# Intended to be invoked by pfSense's ACME certificate renewal hook.
# It expects the renewed certificate and unencrypted private key in the
# current directory as server.crt and server.key.
#
# The destination paths are stable, so renewals do not require any NixOS,
# SOPS, or Synapse configuration changes.
set -euo pipefail

REMOTE="aljam@r820"
CERT="${1:-server.crt}"
KEY="${2:-server.key}"

[[ -f "$CERT" ]] || { echo "missing certificate: $CERT" >&2; exit 1; }
[[ -f "$KEY" ]] || { echo "missing private key: $KEY" >&2; exit 1; }

scp "$CERT" "$REMOTE:/tmp/server.crt"
scp "$KEY" "$REMOTE:/tmp/server.key"

ssh "$REMOTE" 'sudo install -d -o postgres -g postgres -m 700 /var/lib/postgresql/ssl && \
  sudo install -o postgres -g postgres -m 644 /tmp/server.crt /var/lib/postgresql/ssl/server.crt && \
  sudo install -o postgres -g postgres -m 600 /tmp/server.key /var/lib/postgresql/ssl/server.key && \
  sudo chown postgres:postgres /var/lib/postgresql/ssl/server.crt /var/lib/postgresql/ssl/server.key && \
  sudo chmod 644 /var/lib/postgresql/ssl/server.crt && \
  sudo chmod 600 /var/lib/postgresql/ssl/server.key && \
  rm -f /tmp/server.crt /tmp/server.key && \
  sudo systemctl reload postgresql'

echo "PostgreSQL certificate deployed and service reloaded."
